import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/core/services/notification_service.dart';
import 'package:rekber/features/auth/domain/entities/user_entity.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_event.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_state.dart';

class MockApiService extends Mock implements ApiService {}

class MockNotificationService extends Mock implements NotificationService {}

void main() {
  late MockApiService mockApiService;
  late MockNotificationService mockNotificationService;
  late StreamController<void> sessionExpiredController;
  late StreamController<String> fcmTokenRefreshController;

  final testUserJson = {
    'id': 'usr-123',
    'name': 'Test User',
    'email': 'test@rekber.com',
    'role': 'USER',
    'balance': 150000.0,
    'isActive': true,
  };

  final expectedUser = UserEntity(
    id: 'usr-123',
    email: 'test@rekber.com',
    fullName: 'Test User',
    role: 'USER',
    kycStatus: 'none',
    isActive: true,
    createdAt: DateTime.now(),
  );

  setUp(() {
    mockApiService = MockApiService();
    mockNotificationService = MockNotificationService();
    sessionExpiredController = StreamController<void>.broadcast();
    fcmTokenRefreshController = StreamController<String>.broadcast();

    when(() => mockApiService.onSessionExpired)
        .thenAnswer((_) => sessionExpiredController.stream);
    when(() => mockNotificationService.onTokenRefresh)
        .thenAnswer((_) => fcmTokenRefreshController.stream);
    when(() => mockNotificationService.getToken())
        .thenAnswer((_) async => 'fake-fcm-token');
    when(() => mockApiService.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async {});
    when(() => mockApiService.clearTokens()).thenAnswer((_) async {});
  });

  tearDown(() {
    sessionExpiredController.close();
    fcmTokenRefreshController.close();
  });

  group('AuthBloc Tests', () {
    test('Initial state adalah AuthInitial', () {
      final bloc = AuthBloc(
        apiService: mockApiService,
        notificationService: mockNotificationService,
      );
      expect(bloc.state, equals(AuthInitial()));
      bloc.close();
    });

    // ── 1. LOGIN SUKSES & GAGAL ──
    group('AuthLoginRequested', () {
      blocTest<AuthBloc, AuthState>(
        'Login sukses langsung ke backend tanpa Firebase Auth',
        build: () {
          when(() => mockApiService.post('/auth/login', any()))
              .thenAnswer((_) async => {
                    'success': true,
                    'data': {
                      'accessToken': 'valid_access_token',
                      'refreshToken': 'valid_refresh_token',
                      'user': testUserJson,
                    },
                  });
          when(() => mockApiService.post('/auth/update-fcm', any()))
              .thenAnswer((_) async => {'success': true});

          return AuthBloc(
            apiService: mockApiService,
            notificationService: mockNotificationService,
          );
        },
        act: (bloc) => bloc.add(const AuthLoginRequested(
          email: 'test@rekber.com',
          password: 'Password123',
        )),
        expect: () => [
          AuthLoading(),
          isA<AuthAuthenticated>()
              .having((s) => s.user.id, 'user.id', expectedUser.id)
              .having((s) => s.user.email, 'user.email', expectedUser.email)
              .having((s) => s.activeRole, 'activeRole', 'USER'),
        ],
        verify: (_) {
          verify(() => mockApiService.post('/auth/login', {
                'email': 'test@rekber.com',
                'password': 'Password123',
              })).called(1);
          verify(() => mockApiService.saveTokens(
                accessToken: 'valid_access_token',
                refreshToken: 'valid_refresh_token',
              )).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'Login gagal mengembalikan AuthError dengan pesan bahasa Indonesia',
        build: () {
          when(() => mockApiService.post('/auth/login', any())).thenThrow(
            ApiException(
              statusCode: 401,
              message: 'Email atau password salah.',
            ),
          );

          return AuthBloc(
            apiService: mockApiService,
            notificationService: mockNotificationService,
          );
        },
        act: (bloc) => bloc.add(const AuthLoginRequested(
          email: 'wrong@rekber.com',
          password: 'WrongPassword',
        )),
        expect: () => [
          AuthLoading(),
          const AuthError(message: 'Email atau password salah.'),
        ],
      );
    });

    // ── 2. CEK SESI (AUTH CHECK REQUESTED) ──
    group('AuthCheckRequested', () {
      blocTest<AuthBloc, AuthState>(
        'Cek sesi sukses saat token ada dan /auth/me valid',
        build: () {
          when(() => mockApiService.getAccessToken())
              .thenAnswer((_) async => 'stored_access_token');
          when(() => mockApiService.get('/auth/me')).thenAnswer((_) async => {
                'success': true,
                'data': testUserJson,
              });

          return AuthBloc(
            apiService: mockApiService,
            notificationService: mockNotificationService,
          );
        },
        act: (bloc) => bloc.add(AuthCheckRequested()),
        expect: () => [
          AuthLoading(),
          isA<AuthAuthenticated>()
              .having((s) => s.user.id, 'user.id', expectedUser.id)
              .having((s) => s.user.email, 'user.email', expectedUser.email),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'Cek sesi mengembalikan AuthUnauthenticated saat token null di storage',
        build: () {
          when(() => mockApiService.getAccessToken())
              .thenAnswer((_) async => null);

          return AuthBloc(
            apiService: mockApiService,
            notificationService: mockNotificationService,
          );
        },
        act: (bloc) => bloc.add(AuthCheckRequested()),
        expect: () => [
          AuthLoading(),
          AuthUnauthenticated(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'Cek sesi mengembalikan AuthUnauthenticated dan membersihkan token saat /auth/me gagal',
        build: () {
          when(() => mockApiService.getAccessToken())
              .thenAnswer((_) async => 'invalid_or_expired_token');
          when(() => mockApiService.get('/auth/me')).thenThrow(
            ApiException(statusCode: 401, message: 'Token tidak valid.'),
          );

          return AuthBloc(
            apiService: mockApiService,
            notificationService: mockNotificationService,
          );
        },
        act: (bloc) => bloc.add(AuthCheckRequested()),
        expect: () => [
          AuthLoading(),
          AuthUnauthenticated(),
        ],
        verify: (_) {
          verify(() => mockApiService.clearTokens()).called(1);
        },
      );
    });

    // ── 3. LOGOUT ──
    group('AuthLogoutRequested', () {
      blocTest<AuthBloc, AuthState>(
        'Logout memanggil /auth/logout lalu membersihkan penyimpanan token',
        build: () {
          when(() => mockApiService.getRefreshToken())
              .thenAnswer((_) async => 'refresh_token_to_revoke');
          when(() => mockApiService.post('/auth/logout', any()))
              .thenAnswer((_) async => {'success': true});

          return AuthBloc(
            apiService: mockApiService,
            notificationService: mockNotificationService,
          );
        },
        act: (bloc) => bloc.add(AuthLogoutRequested()),
        expect: () => [
          AuthUnauthenticated(),
        ],
        verify: (_) {
          verify(() => mockApiService.post('/auth/logout', {
                'refreshToken': 'refresh_token_to_revoke',
              })).called(1);
          verify(() => mockApiService.clearTokens()).called(1);
        },
      );
    });

    // ── 4. SESSION EXPIRED ──
    group('Session Expired Event', () {
      blocTest<AuthBloc, AuthState>(
        'AuthSessionExpiredEvent memancarkan state AuthSessionExpired',
        build: () => AuthBloc(
          apiService: mockApiService,
          notificationService: mockNotificationService,
        ),
        act: (bloc) => bloc.add(AuthSessionExpiredEvent()),
        expect: () => [
          AuthSessionExpired(),
        ],
      );

      test('Pancaran event dari ApiService.onSessionExpired otomatis memicu AuthSessionExpired',
          () async {
        final bloc = AuthBloc(
          apiService: mockApiService,
          notificationService: mockNotificationService,
        );

        expectLater(
          bloc.stream,
          emits(isA<AuthSessionExpired>()),
        );

        sessionExpiredController.add(null);
        await Future.delayed(const Duration(milliseconds: 20));

        bloc.close();
      });
    });
  });
}
