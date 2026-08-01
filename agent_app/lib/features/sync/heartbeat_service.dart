/// HeartbeatService — mengirim heartbeat ke server dan menerapkan
/// remote config (screenshot_interval, idle_threshold).
library;

import '../../core/api_client.dart';
import '../../core/app_logger.dart';
import '../../core/heartbeat_payload_builder.dart';
import '../../core/runtime_config.dart';

/// Hasil pengiriman heartbeat.
class HeartbeatResult {
  const HeartbeatResult({
    required this.success,
    this.configVersion,
    this.screenshotIntervalSeconds,
    this.idleThresholdSeconds,
    this.errorMessage,
  });

  final bool success;
  final int? configVersion;
  final int? screenshotIntervalSeconds;
  final int? idleThresholdSeconds;
  final String? errorMessage;
}

/// Service heartbeat agent.
class HeartbeatService {
  HeartbeatService({
    required ApiClient apiClient,
    required RuntimeConfig runtimeConfig,
    AppLogger? logger,
  }) : _api = apiClient,
       _runtimeConfig = runtimeConfig,
       _logger = logger ?? AppLogger();

  final ApiClient _api;
  final RuntimeConfig _runtimeConfig;
  final AppLogger _logger;

  /// Kirim heartbeat. `status` & `activityType` sesuai state agent.
  Future<HeartbeatResult> send({
    required String status,
    required String activityType,
    String? currentApp,
    String? currentWindowTitle,
    double? idleDurationSeconds,
  }) async {
    final payload = HeartbeatPayloadBuilder.build(
      status: status,
      activityType: activityType,
      currentApp: currentApp,
      currentWindowTitle: currentWindowTitle,
      idleDurationSeconds: idleDurationSeconds,
    );
    try {
      final response = await _api.postJson('/activities/heartbeat', payload);
      final shot = response['screenshot_interval_seconds'] as int?;
      final idle = response['idle_threshold_seconds'] as int?;
      final version = response['config_version'] as int?;

      if (shot != null && idle != null) {
        _runtimeConfig.applyFromHeartbeat(
          screenshotIntervalSeconds: shot,
          idleThresholdSeconds: idle,
          configVersion: version,
        );
      }
      return HeartbeatResult(
        success: true,
        configVersion: version,
        screenshotIntervalSeconds: shot,
        idleThresholdSeconds: idle,
      );
    } on ApiException catch (e) {
      _logger.warning('Heartbeat', 'Gagal: $e');
      return HeartbeatResult(success: false, errorMessage: e.message);
    }
  }
}
