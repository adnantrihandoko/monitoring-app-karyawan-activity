/// Controller Idle Detector — mengevaluasi idle secara periodik,
/// menghasilkan event `idle`/`active`, dan mengatur state untuk
/// pause/resume tracker lain.
library;

import 'package:flutter/foundation.dart';

import '../../core/activity_buffer.dart';
import '../../core/app_logger.dart';
import '../../core/idle_logic.dart';
import '../../core/runtime_config.dart';
import 'idle_detector.dart';

/// State idle agent saat ini.
enum AgentIdleState { active, idle }

/// Hasil satu pengecekan idle.
class IdleCheckResult {
  const IdleCheckResult({
    required this.state,
    required this.idleMilliseconds,
    required this.thresholdMilliseconds,
  });

  final AgentIdleState state;
  final int idleMilliseconds;
  final int thresholdMilliseconds;
}

/// Memonitor idle, menulis event transisi, dan mengekspos state.
class IdleDetectorController extends ChangeNotifier {
  IdleDetectorController({
    required IdleDetector detector,
    required RuntimeConfig config,
    required ActivityBuffer buffer,
    this.debounceChecks = 2,
    AppLogger? logger,
  }) : _detector = detector,
       _config = config,
       _buffer = buffer,
       _logger = logger ?? AppLogger();

  final IdleDetector _detector;
  final RuntimeConfig _config;
  final ActivityBuffer _buffer;
  final AppLogger _logger;

  /// Berapa kali pengecekan berurutan sebelum transisi idle diyakini.
  final int debounceChecks;

  AgentIdleState _state = AgentIdleState.active;
  int _consecutiveIdle = 0;
  DateTime? _idleStartedAt;

  AgentIdleState get state => _state;
  bool get isIdle => _state == AgentIdleState.idle;
  DateTime? get idleStartedAt => _idleStartedAt;

  /// Threshold idle saat ini (dari remote config).
  int get thresholdSeconds => _config.idleThresholdSeconds;

  /// Membaca durasi idle (ms) langsung dari detector.
  Future<int> idleMilliseconds() => _detector.idleMilliseconds();

  /// Menjalankan satu pengecekan idle. Mengembalikan hasil & state baru.
  Future<IdleCheckResult> checkNow() async {
    final idleMs = await _detector.idleMilliseconds();
    final thresholdMs = _config.idleThresholdSeconds * 1000;
    final eval = IdleLogic.evaluate(
      idleMilliseconds: idleMs,
      thresholdMilliseconds: thresholdMs,
    );

    if (eval.isIdle) {
      _consecutiveIdle++;
      if (_consecutiveIdle >= debounceChecks &&
          _state == AgentIdleState.active) {
        await _transitionToIdle(eval.idleMilliseconds);
      }
    } else {
      _consecutiveIdle = 0;
      if (_state == AgentIdleState.idle) {
        await _transitionToActive();
      }
    }

    return IdleCheckResult(
      state: _state,
      idleMilliseconds: idleMs,
      thresholdMilliseconds: thresholdMs,
    );
  }

  Future<void> _transitionToIdle(int idleMs) async {
    _state = AgentIdleState.idle;
    _idleStartedAt = DateTime.now().toUtc();
    await _buffer.add(
      activityType: 'idle',
      timestamp: DateTime.now().toUtc(),
      durationSeconds: idleMs / 1000.0,
      metadata: {'idle_ms': idleMs, 'threshold_seconds': thresholdSeconds},
    );
    _logger.info('IdleDetector', 'Transisi ke IDLE ($idleMs ms)');
    notifyListeners();
  }

  Future<void> _transitionToActive() async {
    final startedAt = _idleStartedAt ?? DateTime.now().toUtc();
    final now = DateTime.now().toUtc();
    final duration = now.difference(startedAt).inMilliseconds / 1000.0;
    _state = AgentIdleState.active;
    _idleStartedAt = null;
    await _buffer.add(
      activityType: 'active',
      timestamp: now,
      durationSeconds: duration > 0 ? duration : null,
      metadata: {'resumed_from_idle': true},
    );
    _logger.info('IdleDetector', 'Transisi ke ACTIVE');
    notifyListeners();
  }

  /// Menjaga konsistensi saat config threshold berubah (remote).
  void updateConfig() => notifyListeners();
}
