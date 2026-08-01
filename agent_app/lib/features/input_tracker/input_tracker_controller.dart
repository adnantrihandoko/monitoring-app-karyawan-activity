/// Controller Input Tracker — mengumpulkan snapshot input, menghitung delta,
/// dan menulis ringkasan periodik ke buffer lokal.
library;

import 'dart:async';

import '../../core/activity_buffer.dart';
import '../../core/app_logger.dart';
import 'input_aggregator.dart';
import 'input_tracker.dart';

/// Mengumpulkan input dan menghasilkan ringkasan periodik.
class InputTrackerController {
  InputTrackerController({
    required InputTracker tracker,
    required ActivityBuffer buffer,
    this.summaryIntervalSeconds = 60,
    AppLogger? logger,
  }) : _tracker = tracker,
       _buffer = buffer,
       _logger = logger ?? AppLogger(),
       _aggregator = InputAggregator();

  final InputTracker _tracker;
  final ActivityBuffer _buffer;
  final int summaryIntervalSeconds;
  final AppLogger _logger;
  final InputAggregator _aggregator;

  InputCounters _last = const InputCounters.zero();
  Timer? _pollTimer;
  Timer? _flushTimer;
  bool _isPaused = false;

  /// Ringkasan terakhir yang sudah ditulis ke buffer.
  InputSummary? lastSummary;

  /// Memulai polling & jadwal flush periodik.
  void start() {
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => poll());
    _flushTimer = Timer.periodic(
      Duration(seconds: summaryIntervalSeconds),
      (_) => flushToBuffer(),
    );
  }

  /// Menghentikan polling & flush.
  void stop() {
    _pollTimer?.cancel();
    _flushTimer?.cancel();
    _pollTimer = null;
    _flushTimer = null;
  }

  void setPaused(bool paused) => _isPaused = paused;

  /// Satu iterasi polling: ambil snapshot, hitung delta, akumulasi.
  Future<void> poll() async {
    if (_isPaused) return;
    try {
      final snapshot = await _tracker.snapshot();
      final clicks = snapshot.mouseClicks - _last.mouseClicks;
      final keys = snapshot.keyPresses - _last.keyPresses;
      final distance = snapshot.mouseDistance - _last.mouseDistance;
      if (clicks > 0) _aggregator.recordClick();
      if (keys > 0) _aggregator.recordKeyPress();
      if (distance > 0) _aggregator.recordDistance(distance);
      _last = snapshot;
    } catch (e) {
      _logger.warning('InputTrackerController', 'Gagal snapshot: $e');
    }
  }

  /// Menulis ringkasan periode ke buffer sebagai event `active`.
  Future<InputSummary?> flushToBuffer() async {
    if (_isPaused) return null;
    final summary = _aggregator.flush();
    lastSummary = summary;
    await _buffer.add(
      activityType: 'active',
      timestamp: summary.startedAt,
      durationSeconds: summary.durationSeconds > 0
          ? summary.durationSeconds
          : null,
      metadata: summary.toMetadata(),
    );
    return summary;
  }
}
