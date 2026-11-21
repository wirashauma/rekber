import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rekber/core/services/api_service.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.clear();
  }
}

void main() {
  group('ApiService Unit & Concurrency Tests', () {
    late FakeSecureStorage storage;

    setUp(() {
      storage = FakeSecureStorage();
    });

    test('Penyimpanan dan penghapusan token di secure storage', () async {
      final service = ApiService(storage: storage);

      await service.saveTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_123',
      );

      expect(await service.getAccessToken(), 'access_123');
      expect(await service.getRefreshToken(), 'refresh_123');

      await service.clearTokens();

      expect(await service.getAccessToken(), isNull);
      expect(await service.getRefreshToken(), isNull);
    });

    test('Tiga 401 bersamaan memicu TEPAT SATU panggilan /auth/refresh', () async {
      int refreshCallsCount = 0;
      int resource1Calls = 0;
      int resource2Calls = 0;
      int resource3Calls = 0;

      // Initial tokens in storage
      await storage.write(key: 'access_token', value: 'old_expired_access_token');
      await storage.write(key: 'refresh_token', value: 'valid_refresh_token');

      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path.endsWith('/auth/refresh')) {
          refreshCallsCount++;
          // Simulate slight network delay to ensure concurrency overlap
          await Future.delayed(const Duration(milliseconds: 50));
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'accessToken': 'new_rotated_access_token',
                'refreshToken': 'new_rotated_refresh_token',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        final authHeader = request.headers['Authorization'] ?? '';

        if (path.endsWith('/resource1')) {
          resource1Calls++;
          if (authHeader == 'Bearer old_expired_access_token') {
            return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
          }
          if (authHeader == 'Bearer new_rotated_access_token') {
            return http.Response(jsonEncode({'data': 'resource1_data'}), 200);
          }
        }

        if (path.endsWith('/resource2')) {
          resource2Calls++;
          if (authHeader == 'Bearer old_expired_access_token') {
            return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
          }
          if (authHeader == 'Bearer new_rotated_access_token') {
            return http.Response(jsonEncode({'data': 'resource2_data'}), 200);
          }
        }

        if (path.endsWith('/resource3')) {
          resource3Calls++;
          if (authHeader == 'Bearer old_expired_access_token') {
            return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
          }
          if (authHeader == 'Bearer new_rotated_access_token') {
            return http.Response(jsonEncode({'data': 'resource3_data'}), 200);
          }
        }

        return http.Response('Not Found', 404);
      });

      final service = ApiService(client: mockClient, storage: storage);

      // Invoke 3 concurrent requests that will all encounter 401
      final results = await Future.wait([
        service.get('/resource1'),
        service.get('/resource2'),
        service.get('/resource3'),
      ]);

      // Verify that /auth/refresh was called EXACTLY ONCE
      expect(refreshCallsCount, 1);

      // Verify each resource was attempted twice (1st: 401, 2nd retry: 200)
      expect(resource1Calls, 2);
      expect(resource2Calls, 2);
      expect(resource3Calls, 2);

      // Verify all 3 requests received their expected data after the single refresh
      expect(results[0]['data'], 'resource1_data');
      expect(results[1]['data'], 'resource2_data');
      expect(results[2]['data'], 'resource3_data');

      // Verify new tokens are stored
      expect(await service.getAccessToken(), 'new_rotated_access_token');
      expect(await service.getRefreshToken(), 'new_rotated_refresh_token');
    });

    test('Kegagalan refresh token menghapus token dan memancarkan event sessionExpired', () async {
      await storage.write(key: 'access_token', value: 'old_access_token');
      await storage.write(key: 'refresh_token', value: 'revoked_refresh_token');

      final mockClient = MockClient((request) async {
        final path = request.url.path;

        if (path.endsWith('/auth/refresh')) {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'Refresh token sudah kedaluwarsa.',
              'code': 'TOKEN_EXPIRED',
            }),
            401,
          );
        }

        // Return 401 for any other request
        return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
      });

      final service = ApiService(client: mockClient, storage: storage);

      bool sessionExpiredFired = false;
      final sub = service.onSessionExpired.listen((_) {
        sessionExpiredFired = true;
      });

      // Expect request to throw ApiException because refresh failed
      expect(
        () => service.get('/protected-endpoint'),
        throwsA(isA<ApiException>()),
      );

      // Allow microtasks to complete
      await Future.delayed(const Duration(milliseconds: 10));

      expect(sessionExpiredFired, true);
      expect(await service.getAccessToken(), isNull);
      expect(await service.getRefreshToken(), isNull);

      await sub.cancel();
      service.dispose();
    });
  });
}
