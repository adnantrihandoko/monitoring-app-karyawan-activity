/// BatchSyncService — mengirim event dari buffer lokal ke backend
/// via `POST /api/v1/activities/batch` (kontrak FLAT).
library;

import '../../core/activity_buffer.dart';
import '../../core/api_client.dart';
import '../../core/app_logger.dart';
import '../../core/batch_builder.dart';

/// Hasil sinkronisasi batch.
class BatchSyncResult {
  const BatchSyncResult({
    required this.sentCount,
    required this.failedCount,
    this.remainingCount = 0,
    this.errorMessage,
  });

  final int sentCount;
  final int failedCount;
  final int remainingCount;
  final String? errorMessage;

  bool get success => failedCount == 0;
}

/// Menyalin event dari buffer → payload flat → kirim → hapus yang sukses.
class BatchSyncService {
  BatchSyncService({
    required ApiClient apiClient,
    required ActivityBuffer buffer,
    this.batchSize = 50,
    AppLogger? logger,
  }) : _api = apiClient,
       _buffer = buffer,
       _logger = logger ?? AppLogger();

  final ApiClient _api;
  final ActivityBuffer _buffer;
  final int batchSize;
  final AppLogger _logger;

  /// Menjalankan satu siklus sinkronisasi. Mengembalikan jumlah terkirim.
  Future<BatchSyncResult> syncOnce() async {
    final rows = await _buffer.take(batchSize);
    if (rows.isEmpty) {
      return const BatchSyncResult(sentCount: 0, failedCount: 0);
    }

    final items = rows
        .map(
          (r) => ActivityQueueItem(
            activityType: r.activityType,
            timestamp: r.timestamp,
            durationSeconds: r.durationSeconds,
            metadata: r.metadata,
          ),
        )
        .toList();

    try {
      final payload = BatchBuilder.build(items);
      final response = await _api.postJson('/activities/batch', payload);
      final processed =
          (response['processed_count'] as num?)?.toInt() ?? items.length;

      // Hanya hapus item yang diklaim server terproses.
      final removeCount = processed.clamp(0, rows.length);
      await _buffer.removeByIds(
        rows.take(removeCount).map((r) => r.id).toList(),
      );

      final remaining = await _buffer.count();
      return BatchSyncResult(
        sentCount: removeCount,
        failedCount: rows.length - removeCount,
        remainingCount: remaining,
      );
    } on ApiException catch (e) {
      _logger.warning('BatchSync', 'Gagal: $e');
      final remaining = await _buffer.count();
      return BatchSyncResult(
        sentCount: 0,
        failedCount: rows.length,
        remainingCount: remaining,
        errorMessage: e.message,
      );
    }
  }
}
