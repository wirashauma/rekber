import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_event.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_state.dart';

import '../core/services/api_service_test.dart';

void main() {
  test('E2E Alur Otentikasi: Register -> Login -> Tutup/Buka App Tetap Login -> Logout', () async {
    final storage = FakeSecureStorage();

    // In-memory backend simulation for end-to-end integration
    final registeredUsers = <String, Map<String, dynamic>>{};
    final activeSessions = <String, String>{}; // token -> email

    final mockClient = MockClient((request) async {
      final path = request.url.path;

      if (path.endsWith('/auth/register')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final email = body['email'] as String;
        registeredUsers[email] = {
          'id': 'usr-${email.hashCode}',
          'name': body['name'],
          'email': email,
          'role': 'USER',
          'balance': 0.0,
          'isActive': true,
        };
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Registrasi berhasil! Silakan login.',
            'data': registeredUsers[email],
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/auth/login')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final email = body['email'] as String;
        final user = registeredUsers[email];
        if (user != null) {
          const accessToken = 'live_test_access_token_xyz';
          const refreshToken = 'live_test_refresh_token_xyz';
          activeSessions[accessToken] = email;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'accessToken': accessToken,
                'refreshToken': refreshToken,
                'user': user,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'message': 'Email atau password salah.'}),
          401,
        );
      }

      if (path.endsWith('/auth/me')) {
        final authHeader = request.headers['Authorization'] ?? '';
        final token = authHeader.replaceFirst('Bearer ', '');
        final email = activeSessions[token];
        if (email != null && registeredUsers.containsKey(email)) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': registeredUsers[email],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'message': 'Akses ditolak.'}),
          401,
        );
      }

      if (path.endsWith('/auth/logout')) {
        activeSessions.clear();
        return http.Response(
          jsonEncode({'success': true, 'message': 'Logout berhasil.'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/auth/update-fcm')) {
        return http.Response(
          jsonEncode({'success': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('Not Found', 404);
    });

    final service = ApiService(client: mockClient, storage: storage);

    const email = 'e2e_user@rekber.id';
    const password = 'Password123';
    const fullName = 'User E2E Test';

    // ── 1. REGISTER ──
    final bloc1 = AuthBloc(apiService: service);
    bloc1.add(const AuthRegisterRequested(
      email: email,
      password: password,
      fullName: fullName,
      phone: '081234567890',
    ));

    await expectLater(
      bloc1.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthRegistrationSuccess>().having(
          (s) => s.message,
          'message',
          contains('Registrasi berhasil'),
        ),
      ]),
    );
    await bloc1.close();

    // ── 2. LOGIN ──
    final bloc2 = AuthBloc(apiService: service);
    bloc2.add(const AuthLoginRequested(
      email: email,
      password: password,
    ));

    await expectLater(
      bloc2.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthAuthenticated>()
            .having((s) => s.user.email, 'user.email', email)
            .having((s) => s.user.fullName, 'user.fullName', fullName),
      ]),
    );

    // Verifikasi token tersimpan di secure storage
    final accessToken = await service.getAccessToken();
    final refreshToken = await service.getRefreshToken();
    expect(accessToken, isNotNull);
    expect(refreshToken, isNotNull);

    // ── 3. SIMULASI TUTUP & BUKA APP (RESTART APP) ──
    await bloc2.close();

    // Buat BLoC baru dengan storage yang sama (simulasi fresh app instance)
    final bloc3 = AuthBloc(apiService: service);
    bloc3.add(AuthCheckRequested());

    // User tetap terautentikasi (AuthAuthenticated) otomatis
    await expectLater(
      bloc3.stream,
      emitsInOrder([
        isA<AuthLoading>(),
        isA<AuthAuthenticated>()
            .having((s) => s.user.email, 'user.email', email)
            .having((s) => s.user.fullName, 'user.fullName', fullName),
      ]),
    );

    // ── 4. LOGOUT ──
    bloc3.add(AuthLogoutRequested());

    await expectLater(
      bloc3.stream,
      emitsInOrder([
        isA<AuthUnauthenticated>(),
      ]),
    );

    // Verifikasi token telah terhapus dari secure storage
    expect(await service.getAccessToken(), isNull);
    expect(await service.getRefreshToken(), isNull);

    await bloc3.close();
  });
}
