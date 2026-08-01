/// HTTP API client untuk agent.
///
/// Menangani:
/// - Inject Bearer token otomatis pada request ber-auth.
/// - Error handling terstruktur ([ApiException]).
/// - Auto-refresh token saat 401, lalu retry request sekali.
/// - Multipart upload untuk screenshot.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

import 'token_storage.dart';

/// Exception terstruktur untuk semua kegagalan API.
class ApiException implements Exception {
  const ApiException({
    this.statusCode,
    this.message = 'Terjadi kesalahan',
    this.isUnauthorized = false,
    this.isNetworkError = false,
    this.body,
  });

  final int? statusCode;
  final String message;
  final bool isUnauthorized;
  final bool isNetworkError;
  final String? body;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

/// Client HTTP dengan Bearer token & refresh flow.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required TokenStorage tokenStorage,
    http.Client? httpClient,
    this.onSessionExpired,
    Duration timeout = const Duration(seconds: 20),
  }) : _tokens = tokenStorage,
       _http = httpClient ?? http.Client(),
       _timeout = timeout;

  final String baseUrl;
  final TokenStorage _tokens;
  final http.Client _http;
  final Duration _timeout;

  /// Dipanggil ketika refresh gagal (sesi berakhir).
  final Future<void> Function()? onSessionExpired;

  /// Mencegah refresh bersamaan dari banyak request (singleton future).
  Future<void>? _refreshInFlight;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> _jsonHeaders({String? accessToken}) => {
    'Content-Type': 'application/json',
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };

  /// POST JSON. `authRequired` menentukan apakah Bearer token dikirim.
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool authRequired = true,
  }) async {
    final token = authRequired ? await _tokens.readAccessToken() : null;
    final uri = _uri(path);
    var response = await _send(
      () => _http
          .post(
            uri,
            headers: _jsonHeaders(accessToken: token),
            body: jsonEncode(body),
          )
          .timeout(_timeout),
    );

    if (authRequired && response.statusCode == 401) {
      await _refreshTokens();
      final newToken = await _tokens.readAccessToken();
      response = await _send(
        () => _http
            .post(
              uri,
              headers: _jsonHeaders(accessToken: newToken),
              body: jsonEncode(body),
            )
            .timeout(_timeout),
      );
    }

    return _decode(response, expectedStatus: const {200, 201});
  }

  /// GET JSON (ber-auth).
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool authRequired = true,
  }) async {
    final token = authRequired ? await _tokens.readAccessToken() : null;
    final uri = _uri(path);
    var response = await _send(
      () => _http
          .get(uri, headers: _jsonHeaders(accessToken: token))
          .timeout(_timeout),
    );

    if (authRequired && response.statusCode == 401) {
      await _refreshTokens();
      final newToken = await _tokens.readAccessToken();
      response = await _send(
        () => _http
            .get(uri, headers: _jsonHeaders(accessToken: newToken))
            .timeout(_timeout),
      );
    }

    return _decode(response, expectedStatus: const {200});
  }

  /// Upload multipart (untuk endpoint screenshot).
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    required List<int> fileBytes,
    required String fileName,
    required String contentType,
  }) async {
    var response = await _sendMultipart(
      path: path,
      fields: fields,
      fileBytes: fileBytes,
      fileName: fileName,
      contentType: contentType,
    );

    if (response.statusCode == 401) {
      await _refreshTokens();
      response = await _sendMultipart(
        path: path,
        fields: fields,
        fileBytes: fileBytes,
        fileName: fileName,
        contentType: contentType,
      );
    }

    return _decode(response, expectedStatus: const {200, 201});
  }

  Future<http.Response> _sendMultipart({
    required String path,
    required Map<String, String> fields,
    required List<int> fileBytes,
    required String fileName,
    required String contentType,
  }) {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers['Authorization'] = 'Bearer ${_tokens.readAccessToken()}';
    fields.forEach((k, v) => request.fields[k] = v);
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: http_parser.MediaType.parse(contentType),
      ),
    );
    return _http.send(request).timeout(_timeout).then(http.Response.fromStream);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'Gagal terhubung ke server: $e',
        isNetworkError: true,
      );
    }
  }

  Map<String, dynamic> _decode(
    http.Response response, {
    required Set<int> expectedStatus,
  }) {
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        // body non-JSON (misal error HTML) — abaikan.
      }
    }
    if (!expectedStatus.contains(response.statusCode)) {
      throw ApiException(
        statusCode: response.statusCode,
        message: body['detail']?.toString() ?? response.reasonPhrase ?? 'Error',
        isUnauthorized: response.statusCode == 401,
        body: response.body,
      );
    }
    return body;
  }

  /// Melakukan refresh token. Singleton agar request bersamaan tidak
  /// memicu refresh ganda.
  Future<void> _refreshTokens() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final future = _doRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<void> _doRefresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _handleSessionExpired();
      return;
    }

    final uri = _uri('/auth/refresh');
    http.Response response;
    try {
      response = await _http
          .post(
            uri,
            headers: _jsonHeaders(),
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(_timeout);
    } catch (e) {
      await _handleSessionExpired();
      return;
    }

    if (response.statusCode != 200) {
      await _handleSessionExpired();
      return;
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      await _handleSessionExpired();
      return;
    }

    final access = body['access_token'] as String?;
    final refresh = body['refresh_token'] as String?;
    if (access == null || refresh == null) {
      await _handleSessionExpired();
      return;
    }

    await _tokens.saveTokens(accessToken: access, refreshToken: refresh);
  }

  Future<void> _handleSessionExpired() async {
    await _tokens.clear();
    await onSessionExpired?.call();
    throw const ApiException(
      message: 'Sesi berakhir, silakan login ulang',
      isUnauthorized: true,
    );
  }
}
