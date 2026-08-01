import 'package:agent_app/core/heartbeat_payload_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HeartbeatPayloadBuilder', () {
    test('membangun payload heartbeat default', () {
      final payload = HeartbeatPayloadBuilder.build(
        timestamp: DateTime.utc(2026, 8, 1, 9, 0, 0),
      );
      expect(payload['status'], 'active');
      expect(payload['activity_type'], 'active');
      expect(payload['timestamp'], '2026-08-01T09:00:00.000Z');
      expect(payload['current_app'], isNull);
      expect(payload['idle_duration_seconds'], isNull);
    });

    test('status valid ikut dikirim', () {
      final payload = HeartbeatPayloadBuilder.build(
        status: 'idle',
        activityType: 'idle',
        currentApp: 'firefox',
        currentWindowTitle: 'Docs',
        idleDurationSeconds: 120.5,
      );
      expect(payload['status'], 'idle');
      expect(payload['activity_type'], 'idle');
      expect(payload['current_app'], 'firefox');
      expect(payload['current_window_title'], 'Docs');
      expect(payload['idle_duration_seconds'], 120.5);
    });

    test('status tidak valid difallback ke active', () {
      final payload = HeartbeatPayloadBuilder.build(status: 'bogus');
      expect(payload['status'], 'active');
      expect(payload['activity_type'], 'active');
    });

    test('valid statuses mencakup paused', () {
      expect(
        HeartbeatPayloadBuilder.validStatuses,
        containsAll(['active', 'idle', 'away', 'offline', 'paused']),
      );
    });
  });
}
