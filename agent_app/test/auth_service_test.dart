import 'dart:convert';

import 'package:agent_app/core/api_client.dart';
import 'package:agent_app/core/auth_service.dart';
import 'package:agent_app/core/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AuthService', () {
    test('login menyimpan token lalu fetch profile', () async {
      final storage = InMemoryTokenStorage();
      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'ada@example.com');
          expect(request.headers['Authorization'], isNull);
          return http.Response(
            jsonEncode({
              'access_token': 'acc-login',
              'refresh_token': 'ref-login',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/auth/me')) {
          expect(request.headers['Authorization'], 'Bearer acc-login');
          return http.Response(
            jsonEncode({
              'id': 1,
              'email': 'ada@example.com',
              'full_name': 'Ada Lovelace',
              'role': 'karyawan',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
      );
      final auth = AuthService(apiClient: api, tokens: storage);

      final result = await auth.login('ada@example.com', 'secret');
      expect(result.user.email, 'ada@example.com');
      expect(result.user.fullName, 'Ada Lovelace');
      expect(await storage.readAccessToken(), 'acc-login');
      expect(await auth.hasStoredTokens(), isTrue);
    });

    test('login respons tanpa access_token → ApiException', () async {
      final storage = InMemoryTokenStorage();
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'login gagal'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
      );
      final auth = AuthService(apiClient: api, tokens: storage);

      await expectLater(auth.login('a@b.c', 'x'), throwsA(isA<ApiException>()));
    });

    test('logout membersihkan token walau server error', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(accessToken: 'acc', refreshToken: 'ref');

      final mock = MockClient((request) async {
        if (request.url.path.endsWith('/auth/logout')) {
          return http.Response('internal error', 500);
        }
        return http.Response('not found', 404);
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
      );
      final auth = AuthService(apiClient: api, tokens: storage);

      await auth.logout();
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
    });

    test('UserInfo.fromJson mengisi semua field', () {
      final user = UserInfo.fromJson(const {
        'id': 7,
        'email': 'u@x.com',
        'full_name': 'User',
        'role': 'admin',
        'department': 'IT',
      });
      expect(user.id, '7');
      expect(user.department, 'IT');
    });
  });
}
