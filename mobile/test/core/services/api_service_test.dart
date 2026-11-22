import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

    test('HTTP GET, POST, PUT, DELETE return decoded JSON when response is 200', () async {
      final mockClient = MockClient((request) async {
        final body = request.body.isNotEmpty ? jsonDecode(request.body) : {};
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'method': 'GET', 'data': 'ok'}), 200);
        } else if (request.method == 'POST') {
          return http.Response(jsonEncode({'method': 'POST', 'echo': body}), 201);
        } else if (request.method == 'PUT') {
          return http.Response(jsonEncode({'method': 'PUT', 'echo': body}), 200);
        } else if (request.method == 'DELETE') {
          return http.Response(jsonEncode({'method': 'DELETE', 'success': true}), 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = ApiService(client: mockClient, storage: storage);

      final getRes = await service.get('/test');
      expect(getRes['data'], equals('ok'));

      final postRes = await service.post('/test', {'foo': 'bar'});
      expect(postRes['echo']['foo'], equals('bar'));

      final putRes = await service.put('/test', {'foo': 'baz'});
      expect(putRes['echo']['foo'], equals('baz'));

      final delRes = await service.delete('/test');
      expect(delRes['success'], isTrue);

      service.dispose();
    });

    test('HTTP non-200 throws ApiException with parsed message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Data tidak valid.', 'code': 'BAD_REQUEST'}),
          400,
        );
      });

      final service = ApiService(client: mockClient, storage: storage);

      expect(
        () => service.get('/bad-request'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400)),
      );

      service.dispose();
    });

    test('HTTP network failure throws ApiException with status 503', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network unreachable');
      });

      final service = ApiService(client: mockClient, storage: storage);

      expect(
        () => service.get('/network-fail'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)),
      );

      service.dispose();
    });

    test('401 triggers successful refresh and retries original request', () async {
      await storage.write(key: 'access_token', value: 'old_token');
      await storage.write(key: 'refresh_token', value: 'valid_refresh');

      int attempts = 0;
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(jsonEncode({
            'success': true,
            'data': {
              'accessToken': 'refreshed_access',
              'refreshToken': 'refreshed_refresh',
            }
          }), 200);
        }
        attempts++;
        if (attempts == 1) {
          return http.Response(jsonEncode({'message': 'Expired'}), 401);
        }
        return http.Response(jsonEncode({'message': 'Success on retry', 'data': {'ok': true}}), 200);
      });

      final service = ApiService(client: mockClient, storage: storage);
      final res = await service.get('/protected');
      expect(res['data']['ok'], isTrue);
      expect(await service.getAccessToken(), equals('refreshed_access'));
      service.dispose();
    });

    test('401 on /auth/login throws directly without refresh attempt', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'message': 'Invalid credentials'}), 401);
      });

      final service = ApiService(client: mockClient, storage: storage);
      expect(
        () => service.post('/auth/login', {'email': 'a@b.com', 'password': '123'}),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
      service.dispose();
    });

    test('Empty body on 200 returns null', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 204);
      });

      final service = ApiService(client: mockClient, storage: storage);
      final res = await service.get('/empty');
      expect(res, isNull);
      service.dispose();
    });

    test('Error response with errors field and malformed body', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/errors-field')) {
          return http.Response(
            jsonEncode({
              'error': 'Validasi gagal',
              'errors': {'email': 'Email tidak valid'}
            }),
            422,
          );
        }
        return http.Response('<html>Server error</html>', 500);
      });

      final service = ApiService(client: mockClient, storage: storage);

      expect(
        () => service.get('/errors-field'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 422)
            .having((e) => e.message, 'message', 'Validasi gagal')),
      );

      expect(
        () => service.get('/html-error'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 500)
            .having((e) => e.message, 'message', 'Terjadi kesalahan pada server.')),
      );

      service.dispose();
    });

    test('postMultipart sends multipart file and handles response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'data': {'id': 'uploaded-1'}}), 200);
      });

      final service = ApiService(client: mockClient, storage: storage);
      await storage.write(key: 'access_token', value: 'token-123');

      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/test.png')..writeAsStringSync('dummy content');

      final res = await service.postMultipart(
        '/upload',
        fieldName: 'file',
        filePath: tempFile.path,
        fields: {'type': 'PROOF'},
      );

      expect(res['data']['id'], equals('uploaded-1'));
      service.dispose();
      await tempDir.delete(recursive: true);
    });

    test('SocketException throws ApiException with status 503', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('No route to host');
      });

      final service = ApiService(client: mockClient, storage: storage);
      expect(
        () => service.get('/socket-fail'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)),
      );
      service.dispose();
    });

    test('TimeoutException throws ApiException with status 408', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Request timed out');
      });

      final service = ApiService(client: mockClient, storage: storage);
      expect(
        () => service.get('/timeout-fail'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 408)),
      );
      service.dispose();
    });
  });
}
