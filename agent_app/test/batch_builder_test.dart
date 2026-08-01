import 'package:agent_app/core/batch_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BatchBuilder', () {
    test('formatTimestamp menghasilkan UTC ISO-8601', () {
      final dt = DateTime.parse('2026-08-01T09:00:00.000Z');
      expect(BatchBuilder.formatTimestamp(dt), '2026-08-01T09:00:00.000Z');
    });

    test('activity type valid sesuai kontrak backend', () {
      expect(BatchBuilder.isValidActivityType('active'), isTrue);
      expect(BatchBuilder.isValidActivityType('idle'), isTrue);
      expect(BatchBuilder.isValidActivityType('away'), isTrue);
      expect(BatchBuilder.isValidActivityType('offline'), isTrue);
      expect(BatchBuilder.isValidActivityType('paused'), isFalse);
      expect(BatchBuilder.isValidActivityType('unknown'), isFalse);
    });

    test('membangun payload batch flat', () {
      final items = [
        ActivityQueueItem(
          activityType: 'active',
          timestamp: DateTime.utc(2026, 8, 1, 9, 0, 0),
          durationSeconds: 12.5,
          metadata: {'app_name': 'firefox'},
        ),
        ActivityQueueItem(
          activityType: 'idle',
          timestamp: DateTime.utc(2026, 8, 1, 9, 5, 0),
          durationSeconds: 30,
          metadata: {'idle_ms': 30000},
        ),
      ];
      final payload = BatchBuilder.build(items);
      expect(payload.keys, contains('items'));
      final list = payload['items'] as List;
      expect(list, hasLength(2));
      final first = list.first as Map<String, dynamic>;
      expect(first['activity_type'], 'active');
      expect(first['timestamp'], '2026-08-01T09:00:00.000Z');
      expect(first['duration_seconds'], 12.5);
      expect(first['metadata'], {'app_name': 'firefox'});
    });

    test('toPayload default timestamp = now UTC', () {
      final item = ActivityQueueItem(activityType: 'active');
      final payload = item.toPayload();
      expect(payload['activity_type'], 'active');
      expect(payload['timestamp'], isA<String>());
      expect(payload['duration_seconds'], isNull);
      expect(payload['metadata'], isEmpty);
    });
  });
}
