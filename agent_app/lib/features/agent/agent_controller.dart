/// AgentController — orkestrator semua komponen tracking agent.
///
/// Mengatur timer heartbeat, polling app, cek idle, sinkronisasi batch,
/// dan screenshot sesuai interval dari remote config.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/activity_buffer.dart';
import '../../core/agent_status.dart';
import '../../core/app_logger.dart';
import '../../core/auth_service.dart';
import '../../core/config.dart';
import '../../core/runtime_config.dart';
import '../app_tracker/app_tracker_controller.dart';
import '../idle_detector/idle_detector_controller.dart';
import '../input_tracker/input_tracker_controller.dart';
import '../screenshot/screenshot_scheduler.dart';
import '../screenshot/screenshot_service.dart';
import '../sync/batch_sync_service.dart';
import '../sync/heartbeat_service.dart';
import '../../tray/tray_controller.dart';

/// Orkestrator utama agent.
class AgentController extends ChangeNotifier {
  AgentController({
    required AppConfig config,
    required AuthService authService,
    required RuntimeConfig runtimeConfig,
    required ActivityBuffer buffer,
    required AppTrackerController appTracker,
    required InputTrackerController inputTracker,
    required IdleDetectorController idleDetector,
    required ScreenshotService screenshotService,
    required ScreenshotScheduler screenshotScheduler,
    required HeartbeatService heartbeatService,
    required BatchSyncService batchSync,
    required TrayController tray,
    AppLogger? logger,
  }) : _config = config,
       _auth = authService,
       _runtimeConfig = runtimeConfig,
       _buffer = buffer,
       _appTracker = appTracker,
       _inputTracker = inputTracker,
       _idleDetector = idleDetector,
       _screenshotService = screenshotService,
       _screenshotScheduler = screenshotScheduler,
       _heartbeat = heartbeatService,
       _batchSync = batchSync,
       _tray = tray,
       _logger = logger ?? AppLogger();

  final AppConfig _config;
  final AuthService _auth;
  final RuntimeConfig _runtimeConfig;
  final ActivityBuffer _buffer;
  final AppTrackerController _appTracker;
  final InputTrackerController _inputTracker;
  final IdleDetectorController _idleDetector;
  final ScreenshotService _screenshotService;
  final ScreenshotScheduler _screenshotScheduler;
  final HeartbeatService _heartbeat;
  final BatchSyncService _batchSync;
  final TrayController _tray;
  final AppLogger _logger;

  AgentStatus _status = AgentStatus.unauthenticated;
  Timer? _heartbeatTimer;
  Timer? _appPollTimer;
  Timer? _idleTimer;
  Timer? _syncTimer;
  Timer? _screenshotTimer;
  DateTime? _lastHeartbeatAt;
  DateTime? _lastSyncAt;
  int _bufferCount = 0;
  String? _lastError;
  UserInfo? _user;
  int _lastIdleMs = 0;

  AgentStatus get status => _status;
  UserInfo? get user => _user;
  int get bufferCount => _bufferCount;
  DateTime? get lastHeartbeatAt => _lastHeartbeatAt;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;
  bool get isIdle => _idleDetector.isIdle;
  int get idleThresholdSeconds => _runtimeConfig.idleThresholdSeconds;
  int get screenshotIntervalSeconds => _runtimeConfig.screenshotIntervalSeconds;
  RuntimeConfig get runtimeConfig => _runtimeConfig;
  String? get currentApp => _appTracker.current?.appName;
  String? get currentWindowTitle => _appTracker.current?.windowTitle;

  /// Setelah login sukses.
  void setUser(UserInfo user) => _user = user;

  /// Mulai semua timer tracking. Panggil setelah login.
  Future<void> start() async {
    _status = AgentStatus.running;
    _logger.info('Agent', 'Starting agent...');
    _inputTracker.start();
    _heartbeatTimer = Timer.periodic(
      Duration(seconds: _config.heartbeatIntervalSeconds),
      (_) => _onHeartbeatTick(),
    );
    _appPollTimer = Timer.periodic(
      Duration(seconds: _config.appPollIntervalSeconds),
      (_) => _onAppPollTick(),
    );
    _idleTimer = Timer.periodic(
      Duration(seconds: _config.idleCheckIntervalSeconds),
      (_) => _onIdleCheckTick(),
    );
    _syncTimer = Timer.periodic(
      Duration(seconds: _config.batchSyncIntervalSeconds),
      (_) => _onSyncTick(),
    );
    _screenshotTimer = Timer.periodic(
      Duration(seconds: 15),
      (_) => _onScreenshotTick(),
    );
    await _refreshBufferCount();
    // Langsung kirim heartbeat & poll app awal agar server cepat dapat status.
    await _onHeartbeatTick();
    await _onAppPollTick();
    await _updateTrayMenu();
    notifyListeners();
  }

  /// Menghentikan semua timer (logout/exit).
  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    _appPollTimer?.cancel();
    _idleTimer?.cancel();
    _syncTimer?.cancel();
    _screenshotTimer?.cancel();
    _heartbeatTimer = null;
    _appPollTimer = null;
    _idleTimer = null;
    _syncTimer = null;
    _screenshotTimer = null;
    _inputTracker.stop();
    await _appTracker.closeCurrentSession();
  }

  /// Pause tracking (dari tray/UI).
  Future<void> pause() async {
    if (_status == AgentStatus.paused) return;
    _logger.info('Agent', 'Paused');
    _status = AgentStatus.paused;
    _appTracker.setPaused(true);
    _inputTracker.setPaused(true);
    await _updateTrayMenu();
    notifyListeners();
  }

  /// Resume tracking.
  Future<void> resume() async {
    if (_status != AgentStatus.paused) return;
    _logger.info('Agent', 'Resumed');
    _status = _idleDetector.isIdle ? AgentStatus.idle : AgentStatus.running;
    _appTracker.setPaused(_idleDetector.isIdle);
    _inputTracker.setPaused(_idleDetector.isIdle);
    await _updateTrayMenu();
    notifyListeners();
  }

  /// Toggle pause/resume.
  Future<void> togglePause() async {
    if (_status == AgentStatus.paused) {
      await resume();
    } else {
      await pause();
    }
  }

  /// Sinkronisasi manual: kirim heartbeat + batch segera.
  Future<void> syncNow() async {
    await _onHeartbeatTick();
    await _onSyncTick();
  }

  /// Logout: berhenti, tutup sesi, revoke token di server.
  Future<void> logout() async {
    await stop();
    await _auth.logout();
    _status = AgentStatus.unauthenticated;
    _user = null;
    await _updateTrayMenu();
    notifyListeners();
  }

  // ── Timer internals ────────────────────────────────────────────

  Future<void> _onHeartbeatTick() async {
    if (_status == AgentStatus.paused) return;
    final idleMs = await _readIdleMs();
    final result = await _heartbeat.send(
      status: _status.apiValue,
      activityType: _idleDetector.isIdle ? 'idle' : 'active',
      currentApp: currentApp,
      currentWindowTitle: currentWindowTitle,
      idleDurationSeconds: idleMs > 0 ? idleMs / 1000.0 : null,
    );
    if (result.success) {
      _lastHeartbeatAt = DateTime.now();
    }
    notifyListeners();
  }

  Future<void> _onAppPollTick() async {
    if (_status == AgentStatus.paused) return;
    await _appTracker.poll();
    notifyListeners();
  }

  Future<void> _onIdleCheckTick() async {
    if (_status == AgentStatus.paused) return;
    final before = _idleDetector.state;
    final result = await _idleDetector.checkNow();
    _lastIdleMs = result.idleMilliseconds;
    if (before != result.state) {
      // Transisi idle/active: pause/resume sub-trackers.
      _appTracker.setPaused(result.state == AgentIdleState.idle);
      _inputTracker.setPaused(result.state == AgentIdleState.idle);
      _status = result.state == AgentIdleState.idle
          ? AgentStatus.idle
          : AgentStatus.running;
      await _updateTrayMenu();
    }
    notifyListeners();
  }

  Future<void> _onSyncTick() async {
    if (_status == AgentStatus.paused) return;
    final result = await _batchSync.syncOnce();
    _lastSyncAt = DateTime.now();
    if (!result.success && result.errorMessage != null) {
      _lastError = result.errorMessage;
    } else {
      _lastError = null;
    }
    await _refreshBufferCount();
    notifyListeners();
  }

  Future<void> _onScreenshotTick() async {
    if (_status == AgentStatus.paused || !_config.screenshotEnabled) return;
    final decision = _screenshotScheduler.decide(
      intervalSeconds: _runtimeConfig.screenshotIntervalSeconds,
      now: DateTime.now(),
      isIdle: _idleDetector.isIdle,
    );
    if (decision != ScreenshotDecision.capture) return;
    await _screenshotService.captureAndUpload();
  }

  Future<int> _readIdleMs() async {
    try {
      return await _idleDetector.idleMilliseconds();
    } catch (_) {
      return _lastIdleMs;
    }
  }

  Future<void> _refreshBufferCount() async {
    _bufferCount = await _buffer.count();
  }

  Future<void> _updateTrayMenu() async {
    final items = <TrayMenuItem>[
      const TrayMenuItem(
        id: 'show_window',
        label: 'Buka Jendela',
        action: TrayAction.showWindow,
      ),
      TrayMenuItem(
        id: 'toggle_pause',
        label: _status == AgentStatus.paused ? 'Resume' : 'Pause',
        action: TrayAction.togglePause,
        separatorBefore: true,
      ),
      const TrayMenuItem(
        id: 'sync_now',
        label: 'Sync Sekarang',
        action: TrayAction.syncNow,
      ),
      const TrayMenuItem(
        id: 'logout',
        label: 'Logout',
        action: TrayAction.logout,
        separatorBefore: true,
      ),
      const TrayMenuItem(id: 'exit', label: 'Keluar', action: TrayAction.exit),
    ];
    await _tray.setMenu(items);
  }

  /// Handle aksi dari tray.
  Future<void> handleTrayAction(TrayAction action) async {
    switch (action) {
      case TrayAction.togglePause:
        await togglePause();
      case TrayAction.syncNow:
        await syncNow();
      case TrayAction.showWindow:
        await showWindow();
      case TrayAction.logout:
        await logout();
      case TrayAction.exit:
        await exitApp();
    }
  }
}

/// Callback yang di-set dari UI/entry (window_manager).
typedef ShowWindowCallback = Future<void> Function();
typedef ExitAppCallback = Future<void> Function();

// Fungsi eksternal yang di-inject agar AgentController tidak bergantung
// langsung ke window_manager (mudah diuji).
ShowWindowCallback? windowShowHandler;
ExitAppCallback? appExitHandler;

Future<void> showWindow() async {
  if (windowShowHandler != null) {
    await windowShowHandler!();
  }
}

Future<void> exitApp() async {
  if (appExitHandler != null) {
    await appExitHandler!();
  }
}
