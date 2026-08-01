/// Pembangun payload heartbeat sesuai kontrak backend.
///
/// `POST /api/v1/activities/heartbeat` menerima:
/// ```json
/// {
///   "timestamp": "2026-08-01T09:00:00.000Z",
///   "status": "active",
///   "activity_type": "active",
///   "current_app": "firefox",
///   "current_window_title": "Docs",
///   "idle_duration_seconds": 0
/// }
/// ```
/// Status yang valid: `active|idle|away|offline|paused`.
library;

/// Builder murni payload heartbeat (mudah diuji).
class HeartbeatPayloadBuilder {
  HeartbeatPayloadBuilder._();

  static const validStatuses = {'active', 'idle', 'away', 'offline', 'paused'};

  /// Membangun payload heartbeat.
  static Map<String, dynamic> build({
    String status = 'active',
    String activityType = 'active',
    String? currentApp,
    String? currentWindowTitle,
    double? idleDurationSeconds,
    DateTime? timestamp,
  }) {
    final effectiveStatus = validStatuses.contains(status) ? status : 'active';
    final effectiveType = validStatuses.contains(activityType)
        ? activityType
        : 'active';
    return {
      'timestamp': (timestamp ?? DateTime.now().toUtc())
          .toUtc()
          .toIso8601String(),
      'status': effectiveStatus,
      'activity_type': effectiveType,
      'current_app': currentApp,
      'current_window_title': currentWindowTitle,
      'idle_duration_seconds': idleDurationSeconds,
    };
  }
}
