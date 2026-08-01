import 'package:agent_app/core/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryTokenStorage', () {
    test('kosong sebelum ada token', () async {
      final storage = InMemoryTokenStorage();
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
    });

    test('save lalu read', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
      expect(await storage.readAccessToken(), 'acc');
      expect(await storage.readRefreshToken(), 'ref');
    });

    test('clear menghapus token', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
      await storage.clear();
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
    });
  });
}
