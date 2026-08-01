/// Penyimpanan token akses & refresh.
///
/// Abstraksi agar mudah diuji dan bisa diganti implementasinya
/// (flutter_secure_storage untuk produksi, in-memory untuk test).
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kontrak penyimpanan token.
abstract class TokenStorage {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clear();
}

const _kAccessKey = 'agent.access_token';
const _kRefreshKey = 'agent.refresh_token';

/// Implementasi aman memakai flutter_secure_storage (keyring/libsecret di Linux).
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _kAccessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshKey);

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessKey, value: accessToken);
    await _storage.write(key: _kRefreshKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAccessKey);
    await _storage.delete(key: _kRefreshKey);
  }
}

/// Fallback memakai shared_preferences (plain text) untuk environment
/// tanpa keyring. Dipakai bila secure storage gagal inisialisasi.
class PrefsTokenStorage implements TokenStorage {
  PrefsTokenStorage({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  @override
  Future<String?> readAccessToken() async =>
      (await _getPrefs()).getString(_kAccessKey);

  @override
  Future<String?> readRefreshToken() async =>
      (await _getPrefs()).getString(_kRefreshKey);

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final p = await _getPrefs();
    await p.setString(_kAccessKey, accessToken);
    await p.setString(_kRefreshKey, refreshToken);
  }

  @override
  Future<void> clear() async {
    final p = await _getPrefs();
    await p.remove(_kAccessKey);
    await p.remove(_kRefreshKey);
  }
}

/// Implementasi in-memory, digunakan pada unit test.
class InMemoryTokenStorage implements TokenStorage {
  String? _accessToken;
  String? _refreshToken;

  @override
  Future<String?> readAccessToken() async => _accessToken;

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
  }
}
