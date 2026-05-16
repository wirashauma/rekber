import 'dart:convert';
import 'dart:io' show Platform;
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
  final http.Client _client = http.Client();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    } else {
      return 'http://localhost:5000/api';
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'jwt_token');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
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

      String message = 'Terjadi kesalahan';
      dynamic errors;
      try {
        final body = jsonDecode(response.body);
        message = body['message'] ?? body['error'] ?? message;
        errors = body['errors'];
      } catch (e) {
        // Ignored
      }
      throw ApiException(
        statusCode: response.statusCode,
        message: message,
        errors: errors,
      );
    }
  }

  Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await _client.get(uri, headers: await _getHeaders());
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await _client.post(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final response = await _client.put(
      uri,
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }
}
