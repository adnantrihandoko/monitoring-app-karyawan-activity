/// AgentComposer — merakit seluruh komponen agent menjadi [AgentController].
///
/// Dipanggil dari entry point (main.dart). Memisahkan konstruksi dependency
/// dari logika agar mudah diuji.
library;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/activity_buffer.dart';
import '../../core/api_client.dart';
import '../../core/app_logger.dart';
import '../../core/auth_service.dart';
import '../../core/config.dart';
import '../../core/runtime_config.dart';
import '../../core/token_storage.dart';
import '../app_tracker/app_tracker.dart';
import '../app_tracker/app_tracker_controller.dart';
import '../app_tracker/app_tracker_linux.dart';
import '../idle_detector/idle_detector.dart';
import '../idle_detector/idle_detector_controller.dart';
import '../idle_detector/idle_detector_linux.dart';
import '../input_tracker/input_tracker.dart';
import '../input_tracker/input_tracker_controller.dart';
import '../input_tracker/input_tracker_linux.dart';
import '../screenshot/screenshot_capturer.dart';
import '../screenshot/screenshot_capturer_linux.dart';
import '../screenshot/screenshot_scheduler.dart';
import '../screenshot/screenshot_service.dart';
import '../sync/batch_sync_service.dart';
import '../sync/heartbeat_service.dart';
import '../../tray/tray_controller.dart';
import '../../tray/tray_manager_controller.dart';
import 'agent_controller.dart';

/// Tracker yang tidak didukung platform → tidak menghasilkan data.
class UnsupportedAppTracker implements AppTracker {
  @override
  Future<AppWindowInfo?> activeWindow() async => null;
}

/// Tracker input yang tidak didukung platform → counter nol.
class UnsupportedInputTracker implements InputTracker {
  @override
  Future<InputCounters> snapshot() async => const InputCounters.zero();
}

/// Screenshot capturer yang tidak didukung platform → null.
class UnsupportedScreenshotCapturer implements ScreenshotCapturer {
  @override
  Future<CapturedScreenshot?> capture() async => null;
}

/// Kumpulan komponen yang sudah dirakit.
class AgentComponents {
  AgentComponents({
    required this.config,
    required this.apiClient,
    required this.authService,
    required this.buffer,
    required this.controller,
  });

  final AppConfig config;
  final ApiClient apiClient;
  final AuthService authService;
  final ActivityBuffer buffer;
  final AgentController controller;
}

/// Merakit semua komponen agent.
class AgentComposer {
  AgentComposer._();

  /// Membangun komponen agent secara penuh.
  static Future<AgentComponents> compose({
    AppConfig? config,
    TokenStorage? tokenStorage,
    TrayController? tray,
  }) async {
    sqfliteFfiInit();
    final cfg = config ?? AppConfig.fromEnvironment();

    final tokens = tokenStorage ?? SecureTokenStorage();

    // Tray: coba tray_manager, fallback no-op bila gagal (mis. tanpa
    // libayatana-appindicator di Linux).
    var trayController = tray ?? NullTrayController();
    if (tray == null) {
      final managerTray = TrayManagerController();
      try {
        await managerTray.init();
        trayController = managerTray;
      } catch (_) {
        // Tray tidak didukung — lanjut tanpa tray.
      }
    }

    final api = ApiClient(baseUrl: cfg.apiBaseUrl, tokenStorage: tokens);

    final auth = AuthService(apiClient: api, tokens: tokens);

    // Database lokal di direktori support aplikasi.
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'agent_activity.db');
    final database = await ActivityDatabase.open(path: dbPath);
    final buffer = ActivityBuffer(database: database);

    final runtimeConfig = RuntimeConfig(
      screenshotIntervalSeconds: cfg.defaultScreenshotIntervalSeconds,
      idleThresholdSeconds: cfg.defaultIdleThresholdSeconds,
    );

    final logger = AppLogger();

    final appTracker = AppTrackerController(
      tracker: AppConfig.isLinux()
          ? LinuxAppTracker()
          : UnsupportedAppTracker(),
      buffer: buffer,
      logger: logger,
    );

    final inputTracker = InputTrackerController(
      tracker: cfg.inputTrackingEnabled && AppConfig.isLinux()
          ? LinuxInputTracker(logger: logger)
          : UnsupportedInputTracker(),
      buffer: buffer,
      summaryIntervalSeconds: cfg.inputSummaryIntervalSeconds,
      logger: logger,
    );

    final idleDetector = IdleDetectorController(
      detector: AppConfig.isLinux()
          ? LinuxIdleDetector(logger: logger)
          : StaticIdleDetector(0),
      config: runtimeConfig,
      buffer: buffer,
      logger: logger,
    );

    final screenshotService = ScreenshotService(
      capturer: AppConfig.isLinux()
          ? LinuxScreenshotCapturer(logger: logger)
          : UnsupportedScreenshotCapturer(),
      apiClient: api,
      logger: logger,
    );

    final heartbeat = HeartbeatService(
      apiClient: api,
      runtimeConfig: runtimeConfig,
      logger: logger,
    );

    final batchSync = BatchSyncService(
      apiClient: api,
      buffer: buffer,
      batchSize: cfg.batchSize,
      logger: logger,
    );

    final controller = AgentController(
      config: cfg,
      authService: auth,
      runtimeConfig: runtimeConfig,
      buffer: buffer,
      appTracker: appTracker,
      inputTracker: inputTracker,
      idleDetector: idleDetector,
      screenshotService: screenshotService,
      screenshotScheduler: ScreenshotScheduler(),
      heartbeatService: heartbeat,
      batchSync: batchSync,
      tray: trayController,
      logger: logger,
    );

    // Wire aksi tray ke controller.
    if (trayController is TrayManagerController) {
      trayController.onAction = controller.handleTrayAction;
    }

    return AgentComponents(
      config: cfg,
      apiClient: api,
      authService: auth,
      buffer: buffer,
      controller: controller,
    );
  }
}
