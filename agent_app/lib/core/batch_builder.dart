/// Pembangun payload batch — kontrak FLAT dari backend.
///
/// Backend menerima:
/// ```json
/// {
///   "items": [
///     {
///       "timestamp": "2026-08-01T09:00:00.000Z",
///       "activity_type": "active",
///       "duration_seconds": 12.5,
///       "metadata": { "app_name": "firefox", "window_title": "Docs" }
///     }
///   ]
/// }
/// ```
/// (lihat `backend/app/schemas/activities.py` → `ActivityBatchRequest`).
library;

/// Satu item aktivitas yang akan masuk buffer lokal / payload batch.
class ActivityQueueItem {
  const ActivityQueueItem({
    required this.activityType,
    this.timestamp,
    this.durationSeconds,
    this.metadata,
  });

  final String activityType;
  final DateTime? timestamp;
  final double? durationSeconds;
  final Map<String, dynamic>? metadata;

  /// Waktu event (default now UTC).
  DateTime get effectiveTimestamp => timestamp ?? DateTime.now().toUtc();

  /// Payload flat sesuai kontrak backend.
  Map<String, dynamic> toPayload() => {
    'timestamp': BatchBuilder.formatTimestamp(effectiveTimestamp),
    'activity_type': activityType,
    'duration_seconds': durationSeconds,
    'metadata': metadata ?? {},
  };
}

/// Builder payload batch.
class BatchBuilder {
  BatchBuilder._();

  /// Format timestamp UTC ISO-8601 yang diterima Pydantic.
  static String formatTimestamp(DateTime dt) => dt.toUtc().toIso8601String();

  /// Nilai activity_type yang valid sesuai enum backend.
  static const validActivityTypes = {'active', 'idle', 'away', 'offline'};

  static bool isValidActivityType(String value) =>
      validActivityTypes.contains(value);

  /// Membangun payload batch flat `{ items: [...] }`.
  static Map<String, dynamic> build(List<ActivityQueueItem> items) => {
    'items': items.map((e) => e.toPayload()).toList(),
  };
}
