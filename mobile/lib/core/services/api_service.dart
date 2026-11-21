import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic errors;

  ApiException({required this.statusCode, required this.message, this.errors});

  @override
  String toString() => 'ApiException: $statusCode $message';
}

class ApiService {
  final http.Client _client;
  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _legacyTokenKey = 'jwt_token';

  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();

  Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  Future<bool>? _refreshFuture;

  ApiService({
    http.Client? client,
    FlutterSecureStorage? storage,
  })  : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5000/api';
      }
    } catch (_) {
      // Platform not supported or test environment
    }
    return 'http://localhost:5000/api';
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _legacyTokenKey, value: accessToken);
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
    await _storage.write(key: _legacyTokenKey, value: token);
  }

  Future<String?> getAccessToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token != null && token.isNotEmpty) {
      return token;
    }
    return await _storage.read(key: _legacyTokenKey);
  }

  Future<String?> getToken() async => getAccessToken();

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _legacyTokenKey);
  }

  Future<void> clearToken() async => clearTokens();

  Future<Map<String, String>> _getHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  void _emitSessionExpired() {
    if (!_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(null);
    }
  }

  Future<bool> _tryRefreshToken() {
    _refreshFuture ??= _performRefreshToken().whenComplete(() {
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  Future<bool> _performRefreshToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await clearTokens();
      _emitSessionExpired();
      return false;
    }

    try {
      final uri = Uri.parse('$baseUrl/auth/refresh');
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body);
        final data = body['data'];
        final newAccessToken = data['accessToken'] ?? data['token'];
        final newRefreshToken = data['refreshToken'];

        if (newAccessToken != null && newRefreshToken != null) {
          await saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          return true;
        }
      }

      await clearTokens();
      _emitSessionExpired();
      return false;
    } catch (_) {
      await clearTokens();
      _emitSessionExpired();
      return false;
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      if (kDebugMode) {
        print('--- API ERROR ---');
        print('Status Code: ${response.statusCode}');
        print('Endpoint: ${response.request?.url}');
        print('Response Body: ${response.body}');
        print('-----------------');
      }

      String message = 'Terjadi kesalahan pada server.';
      dynamic errors;
      try {
        final body = jsonDecode(response.body);
        message = body['message'] ?? body['error'] ?? message;
        errors = body['errors'];
      } catch (_) {}

      throw ApiException(
        statusCode: response.statusCode,
        message: message,
        errors: errors,
      );
    }
  }

  Future<dynamic> _sendRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    http.Response response;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          response = await _client
              .post(uri,
                  headers: headers,
                  body: body != null ? jsonEncode(body) : null)
              .timeout(const Duration(seconds: 20));
          break;
        case 'PUT':
          response = await _client
              .put(uri,
                  headers: headers,
                  body: body != null ? jsonEncode(body) : null)
              .timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        default:
          throw ApiException(
            statusCode: 400,
            message: 'Metode HTTP $method tidak didukung.',
          );
      }
    } on TimeoutException {
      throw ApiException(
        statusCode: 408,
        message: 'Koneksi time out. Periksa jaringan Anda dan coba lagi.',
      );
    } on SocketException {
      throw ApiException(
        statusCode: 503,
        message:
            'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    } on http.ClientException {
      throw ApiException(
        statusCode: 503,
        message:
            'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
      );
    }

    // 401 Unauthorized handling with token refresh
    final isAuthEndpoint = endpoint.startsWith('/auth/login') ||
        endpoint.startsWith('/auth/refresh') ||
        endpoint.startsWith('/auth/register');

    if (response.statusCode == 401 && !isRetry && !isAuthEndpoint) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        return _sendRequest(method, endpoint, body: body, isRetry: true);
      }
    }

    return _handleResponse(response);
  }

  Future<dynamic> get(String endpoint) async {
    return _sendRequest('GET', endpoint);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    return _sendRequest('POST', endpoint, body: body);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    return _sendRequest('PUT', endpoint, body: body);
  }

  Future<dynamic> delete(String endpoint) async {
    return _sendRequest('DELETE', endpoint);
  }

  void dispose() {
    _sessionExpiredController.close();
  }
}
