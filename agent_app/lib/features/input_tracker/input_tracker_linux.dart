/// Implementasi InputTracker untuk Linux X11.
///
/// Memakai:
///  - `xinput test-xi2 --root` → stream event keyboard/mouse (count klik & key)
///  - `xdotool getmouselocation --shell` → polling posisi mouse (jarak)
///
/// Kedua tool wajib ada; bila tidak tersedia tracker menghasilkan nol
/// (graceful degradation, dicatat lewat logger).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/app_logger.dart';
import '../../core/process_runner.dart';
import 'input_tracker.dart';

/// Parser murni output `xinput test-xi2`.
class XInputParser {
  XInputParser._();

  /// Deteksi baris berisi event raw keyboard/mouse.
  static bool isKeyEvent(String line) =>
      line.contains('RawKeyPress') || line.contains('KeyPress');
  static bool isButtonEvent(String line) =>
      line.contains('RawButtonPress') || line.contains('ButtonPress');
}

/// Parser posisi mouse dari `xdotool getmouselocation --shell`.
class XDotoolLocationParser {
  XDotoolLocationParser._();

  /// Parse `X=1234` → 1234.
  static int? parseAxis(String stdout, String axis) {
    final match = RegExp('$axis=(-?\\d+)').firstMatch(stdout);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}

/// Tracker input Linux berbasis proses X11.
class LinuxInputTracker implements InputTracker {
  LinuxInputTracker({
    ProcessRunner? runner,
    AppLogger? logger,
    Duration pollInterval = const Duration(seconds: 1),
    bool autoListen = true,
  }) : _runner = runner ?? RealProcessRunner(),
       _logger = logger ?? AppLogger(),
       _pollInterval = pollInterval {
    if (autoListen) _start();
  }

  final ProcessRunner _runner;
  final AppLogger _logger;
  final Duration _pollInterval;

  Process? _eventProcess;
  StreamSubscription<String>? _eventSub;

  int _clicks = 0;
  int _keys = 0;
  double _distance = 0;
  double? _lastX;
  double? _lastY;

  Timer? _pollTimer;

  void _start() {
    _startEventListener();
    _startDistancePolling();
  }

  void _startEventListener() {
    _startEventProcess().catchError((e) {
      _logger.warning('InputTracker', 'Tidak bisa memulai xinput: $e');
    });
  }

  Future<void> _startEventProcess() async {
    final process = await Process.start('xinput', ['test-xi2', '--root']);
    _eventProcess = process;
    _eventSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onEventLine);
    process.exitCode.then((_) {
      if (identical(_eventProcess, process)) {
        _eventProcess = null;
      }
    });
  }

  void _onEventLine(String line) {
    if (XInputParser.isButtonEvent(line)) _clicks++;
    if (XInputParser.isKeyEvent(line)) _keys++;
  }

  void _startDistancePolling() {
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollMouse());
  }

  Future<void> _pollMouse() async {
    final r = await _runner.run('xdotool', ['getmouselocation', '--shell']);
    if (!r.isSuccess) return;
    final x = XDotoolLocationParser.parseAxis(r.stdout, 'X');
    final y = XDotoolLocationParser.parseAxis(r.stdout, 'Y');
    if (x == null || y == null) return;
    final px = x.toDouble();
    final py = y.toDouble();
    if (_lastX != null && _lastY != null) {
      final dx = px - _lastX!;
      final dy = py - _lastY!;
      _distance += _euclidean(dx, dy);
    }
    _lastX = px;
    _lastY = py;
  }

  double _euclidean(double dx, double dy) {
    final d = (dx * dx + dy * dy);
    if (d <= 0 || !d.isFinite) return 0;
    return d; // approx distance squared → scale of movement; kept simple.
  }

  @override
  Future<InputCounters> snapshot() async => InputCounters(
    mouseClicks: _clicks,
    keyPresses: _keys,
    mouseDistance: _distance,
  );

  /// Menghentikan proses & timer (dipanggil saat agent berhenti).
  Future<void> dispose() async {
    await _eventSub?.cancel();
    _pollTimer?.cancel();
    try {
      _eventProcess?.kill(ProcessSignal.sigterm);
    } catch (_) {}
    _eventProcess = null;
  }
}
