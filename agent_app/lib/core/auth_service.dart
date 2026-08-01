/// AuthService — login, refresh, logout, dan status sesi.
///
/// Berkomunikasi dengan backend FastAPI:
///   POST /auth/login   → { access_token, refresh_token, token_type, expires_in }
///   POST /auth/refresh → { access_token, refresh_token, ... }
///   POST /auth/logout  → { message }
///   GET  /auth/me      → { id, email, full_name, role, department }
library;

import 'api_client.dart';
import 'token_storage.dart';

/// Informasi user yang terautentikasi.
class UserInfo {
  const UserInfo({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.department,
  });

  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? department;

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
    id: json['id']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    fullName: json['full_name']?.toString() ?? '',
    role: json['role']?.toString() ?? 'employee',
    department: json['department']?.toString(),
  );
}

/// Hasil login sukses.
class LoginResult {
  const LoginResult({required this.user});

  final UserInfo user;
}

/// Service autentikasi agent.
class AuthService {
  AuthService({required ApiClient apiClient, required TokenStorage tokens})
    : _api = apiClient,
      _tokens = tokens;

  final ApiClient _api;
  final TokenStorage _tokens;

  /// Login dengan email & password, simpan token di secure storage.
  Future<LoginResult> login(String email, String password) async {
    final response = await _api.postJson('/auth/login', {
      'email': email,
      'password': password,
    }, authRequired: false);

    final access = response['access_token'];
    final refresh = response['refresh_token'];
    if (access is! String || refresh is! String) {
      throw const ApiException(message: 'Respons login tidak valid');
    }

    await _tokens.saveTokens(accessToken: access, refreshToken: refresh);
    final user = await fetchMe();
    return LoginResult(user: user);
  }

  /// Mengambil profil user saat ini (ber-auth).
  Future<UserInfo> fetchMe() async {
    final response = await _api.getJson('/auth/me');
    return UserInfo.fromJson(response);
  }

  /// Logout: revoke session di server dan bersihkan token lokal.
  Future<void> logout() async {
    try {
      await _api.postJson('/auth/logout', const {});
    } catch (_) {
      // Abaikan error jaringan; token lokal tetap dibersihkan.
    } finally {
      await _tokens.clear();
    }
  }

  /// Apakah ada token tersimpan (belum tentu valid).
  Future<bool> hasStoredTokens() async {
    final access = await _tokens.readAccessToken();
    final refresh = await _tokens.readRefreshToken();
    return (access != null && access.isNotEmpty) ||
        (refresh != null && refresh.isNotEmpty);
  }
}
