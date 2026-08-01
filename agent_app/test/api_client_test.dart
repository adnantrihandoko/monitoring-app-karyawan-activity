import 'dart:convert';

import 'package:agent_app/core/api_client.dart';
import 'package:agent_app/core/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiClient', () {
    test('postJson mengirim Bearer token dan decode JSON', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(accessToken: 'acc1', refreshToken: 'ref1');

      final mock = MockClient((request) async {
        expect(request.url.path.endsWith('/activities/heartbeat'), isTrue);
        expect(request.headers['Authorization'], 'Bearer acc1');
        return http.Response(
          jsonEncode({'status': 'ok'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
      );

      final result = await api.postJson('/activities/heartbeat', {'a': 1});
      expect(result['status'], 'ok');
    });

    test('401 memicu refresh lalu retry request', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(accessToken: 'old', refreshToken: 'refresh1');

      var attempts = 0;
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          expect(request.headers['Authorization'], isNull);
          return http.Response(
            jsonEncode({'access_token': 'new-acc', 'refresh_token': 'new-ref'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        attempts++;
        if (attempts == 1) {
          expect(request.headers['Authorization'], 'Bearer old');
          return http.Response('{"detail":"unauthorized"}', 401);
        }
        expect(request.headers['Authorization'], 'Bearer new-acc');
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
      );

      final result = await api.postJson('/activities/batch', {'items': []});
      expect(result['ok'], isTrue);
      expect(attempts, 2);
      expect(await storage.readAccessToken(), 'new-acc');
      expect(await storage.readRefreshToken(), 'new-ref');
    });

    test(
      'refresh gagal memanggil onSessionExpired & melempar ApiException',
      () async {
        final storage = InMemoryTokenStorage();
        await storage.saveTokens(accessToken: 'old', refreshToken: 'refresh1');

        var expiredCalled = false;
        final mock = MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            return http.Response('{"detail":"invalid"}', 401);
          }
          return http.Response('{"detail":"unauthorized"}', 401);
        });

        final api = ApiClient(
          baseUrl: 'http://localhost:8000/api/v1',
          tokenStorage: storage,
          httpClient: mock,
          onSessionExpired: () async => expiredCalled = true,
        );

        await expectLater(
          api.postJson('/activities/heartbeat', {}),
          throwsA(
            isA<ApiException>().having(
              (e) => e.isUnauthorized,
              'isUnauthorized',
              isTrue,
            ),
          ),
        );
        expect(expiredCalled, isTrue);
        expect(await storage.readAccessToken(), isNull);
      },
    );

    test('tidak ada refresh token → sesi berakhir langsung', () async {
      final storage = InMemoryTokenStorage();
      var expiredCalled = false;
      final mock = MockClient((request) async {
        return http.Response('{"detail":"unauthorized"}', 401);
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
        onSessionExpired: () async => expiredCalled = true,
      );

      await expectLater(
        api.postJson('/auth/me', {}, authRequired: true),
        throwsA(isA<ApiException>()),
      );
      expect(expiredCalled, isTrue);
    });

    test('network error → ApiException isNetworkError', () async {
      final storage = InMemoryTokenStorage();
      final mock = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
      );

      await expectLater(
        api.getJson('/auth/me'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isNetworkError,
            'isNetworkError',
            isTrue,
          ),
        ),
      );
    });

    test('non-2xx melempar ApiException dengan status', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
      final mock = MockClient((request) async {
        return http.Response('{"detail":"validation error"}', 422);
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
      );

      await expectLater(
        api.postJson('/activities/batch', {}),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 422),
        ),
      );
    });
  });
}
