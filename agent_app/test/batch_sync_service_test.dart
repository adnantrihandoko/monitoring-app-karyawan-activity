import 'dart:convert';

import 'package:agent_app/core/activity_buffer.dart';
import 'package:agent_app/core/api_client.dart';
import 'package:agent_app/core/token_storage.dart';
import 'package:agent_app/features/sync/batch_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  group('BatchSyncService', () {
    test('syncOnce mengirim batch flat & menghapus item terproses', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
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

      late Map<String, dynamic> sentBody;
      final mock = MockClient((request) async {
        expect(request.url.path.endsWith('/activities/batch'), isTrue);
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'processed_count': 2}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
      );
      final service = BatchSyncService(apiClient: api, buffer: buffer);

      final result = await service.syncOnce();

      expect(result.sentCount, 2);
      expect(result.failedCount, 0);
      expect(await buffer.count(), 0);
      final items = (sentBody['items'] as List).cast<Map<String, dynamic>>();
      expect(items, hasLength(2));
      expect(items.first['activity_type'], 'active');
    });

    test('syncOnce tanpa item tidak memanggil API', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
      var called = false;
      final mock = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
      );
      final service = BatchSyncService(apiClient: api, buffer: buffer);

      final result = await service.syncOnce();
      expect(result.sentCount, 0);
      expect(called, isFalse);
    });

    test('syncOnce gagal menyimpan item di buffer', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
      await buffer.add(activityType: 'active');

      final mock = MockClient((request) async {
        return http.Response('{"detail":"boom"}', 500);
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
      );
      final service = BatchSyncService(apiClient: api, buffer: buffer);

      final result = await service.syncOnce();
      expect(result.sentCount, 0);
      expect(result.failedCount, 1);
      expect(result.errorMessage, isNotEmpty);
      expect(await buffer.count(), 1, reason: 'item tidak boleh hilang');
    });

    test('processed_count < total hanya menghapus yang diklaim', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
      await buffer.add(activityType: 'active');
      await buffer.add(activityType: 'idle');

      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({'processed_count': 1}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
      );
      final service = BatchSyncService(apiClient: api, buffer: buffer);

      final result = await service.syncOnce();
      expect(result.sentCount, 1);
      expect(result.failedCount, 1);
      expect(await buffer.count(), 1);
    });
  });
}
