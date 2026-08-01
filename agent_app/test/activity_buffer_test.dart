import 'package:agent_app/core/activity_buffer.dart';
import 'package:agent_app/core/agent_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Database db;
  late ActivityBuffer buffer;

  setUp(() async {
    db = await ActivityDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    buffer = ActivityBuffer(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('ActivityBuffer', () {
    test('add dan count', () async {
      await buffer.add(
        activityType: 'active',
        timestamp: DateTime.utc(2026, 8, 1, 9, 0, 0),
        durationSeconds: 10,
        metadata: {'app': 'code'},
      );
      expect(await buffer.count(), 1);
    });

    test('take mengembalikan antrean paling lama dulu', () async {
      await buffer.add(
        activityType: 'active',
        timestamp: DateTime.utc(2026, 8, 1, 9, 0, 0),
        durationSeconds: 10,
      );
      await buffer.add(
        activityType: 'idle',
        timestamp: DateTime.utc(2026, 8, 1, 9, 1, 0),
        durationSeconds: 20,
      );
      await buffer.add(
        activityType: 'away',
        timestamp: DateTime.utc(2026, 8, 1, 9, 2, 0),
        durationSeconds: 30,
      );
      final batch = await buffer.take(2);
      expect(batch, hasLength(2));
      expect(batch.first.activityType, 'active');
      expect(batch[1].activityType, 'idle');
      expect(await buffer.count(), 3, reason: 'take tidak menghapus');
    });

    test('removeByIds menghapus item terkirim', () async {
      await buffer.add(
        activityType: 'active',
        timestamp: DateTime.utc(2026, 8, 1, 9, 0, 0),
        durationSeconds: 10,
      );
      await buffer.add(
        activityType: 'idle',
        timestamp: DateTime.utc(2026, 8, 1, 9, 1, 0),
        durationSeconds: 20,
      );
      final batch = await buffer.take(10);
      expect(batch, hasLength(2));

      await buffer.removeByIds([batch.first.id]);
      expect(await buffer.count(), 1);

      final remaining = await buffer.take(10);
      expect(remaining.single.activityType, 'idle');
    });

    test('trim antrian saat melebihi maxQueueSize', () async {
      final small = ActivityBuffer(database: db, maxQueueSize: 3);
      for (var i = 0; i < 5; i++) {
        await small.add(
          activityType: 'active',
          timestamp: DateTime.utc(2026, 8, 1, 9, 0, i),
        );
      }
      expect(await small.count(), 3, reason: 'overflow di-trim');
    });
  });

  group('ActivityType', () {
    test('mapping value sesuai kontrak backend', () {
      expect(ActivityType.active.value, 'active');
      expect(ActivityType.idle.value, 'idle');
      expect(ActivityType.away.value, 'away');
      expect(ActivityType.offline.value, 'offline');
    });
  });
}
