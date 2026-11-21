import 'package:flutter_test/flutter_test.dart';
import 'package:rekber/config/routes/app_router.dart';
import 'package:rekber/features/auth/domain/entities/user_entity.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_state.dart';

void main() {
  group('Route Guard Pure Redirect Tests (computeAuthRedirect)', () {
    final regularUser = UserEntity(
      id: 'user-123',
      email: 'user@example.com',
      fullName: 'Regular User',
      role: 'USER',
      kycStatus: 'verified',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

    final adminUser = UserEntity(
      id: 'admin-123',
      email: 'admin@example.com',
      fullName: 'Admin User',
      role: 'ADMIN',
      kycStatus: 'verified',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

    // ── 1. GUEST / UNAUTHENTICATED ──
    group('Guest (Unauthenticated)', () {
      final guestState = AuthUnauthenticated();

      test('Belum login mengakses /home diarahkan ke /login', () {
        final redirect = AppRouter.computeAuthRedirect(
          location: '/home',
          authState: guestState,
        );
        expect(redirect, '/login');
      });

      test('Belum login mengakses rute public auth diperbolehkan (return null)', () {
        expect(
          AppRouter.computeAuthRedirect(location: '/login', authState: guestState),
          isNull,
        );
        expect(
          AppRouter.computeAuthRedirect(location: '/register', authState: guestState),
          isNull,
        );
        expect(
          AppRouter.computeAuthRedirect(location: '/forgot-password', authState: guestState),
          isNull,
        );
        expect(
          AppRouter.computeAuthRedirect(location: '/reset-password', authState: guestState),
          isNull,
        );
      });

      test('Belum login deep link ke /admin diarahkan ke /login', () {
        final redirect = AppRouter.computeAuthRedirect(
          location: '/admin/dashboard',
          authState: guestState,
        );
        expect(redirect, '/login');
      });
    });

    // ── 2. USER (REGULAR) ──
    group('User Biasa (Role: USER)', () {
      final userState = AuthAuthenticated(user: regularUser, activeRole: 'USER');

      test('Sudah login mengakses /login diarahkan ke /home', () {
        final redirect = AppRouter.computeAuthRedirect(
          location: '/login',
          authState: userState,
        );
        expect(redirect, '/home');
      });

      test('Sudah login mengakses /register diarahkan ke /home', () {
        final redirect = AppRouter.computeAuthRedirect(
          location: '/register',
          authState: userState,
        );
        expect(redirect, '/home');
      });

      test('Sudah login mengakses /home diperbolehkan (return null)', () {
        final redirect = AppRouter.computeAuthRedirect(
          location: '/home',
          authState: userState,
        );
        expect(redirect, isNull);
      });

      test('User biasa deep link ke /admin/* dilarang dan diarahkan ke /home', () {
        final redirect = AppRouter.computeAuthRedirect(
          location: '/admin/dashboard',
          authState: userState,
        );
        expect(redirect, '/home');

        final redirectUsers = AppRouter.computeAuthRedirect(
          location: '/admin/settings/users',
          authState: userState,
        );
        expect(redirectUsers, '/home');
      });
    });

    // ── 3. ADMIN (Role: ADMIN) ──
    group('Admin Platform (Role: ADMIN)', () {
      final adminState = AuthAuthenticated(user: adminUser, activeRole: 'ADMIN');

      test('Admin deep link ke /admin/* diperbolehkan (return null)', () {
        expect(
          AppRouter.computeAuthRedirect(location: '/admin/dashboard', authState: adminState),
          isNull,
        );
        expect(
          AppRouter.computeAuthRedirect(location: '/admin/settings', authState: adminState),
          isNull,
        );
      });

      test('Admin mengakses /login diarahkan ke /admin/dashboard', () {
        final redirect = AppRouter.computeAuthRedirect(
          location: '/login',
          authState: adminState,
        );
        expect(redirect, '/admin/dashboard');
      });

      test('Admin mengakses /home diperbolehkan (return null)', () {
        final redirect = AppRouter.computeAuthRedirect(
          location: '/home',
          authState: adminState,
        );
        expect(redirect, isNull);
      });
    });

    // ── 4. SESSION EXPIRED ──
    group('Session Expired', () {
      final expiredState = AuthSessionExpired();

      test('SessionExpired diarahkan ke /login', () {
        final redirect = AppRouter.computeAuthRedirect(
          location: '/home',
          authState: expiredState,
        );
        expect(redirect, '/login');
      });

      test('SessionExpired saat sudah di /login tetap di /login (return null)', () {
        final redirect = AppRouter.computeAuthRedirect(
          location: '/login',
          authState: expiredState,
        );
        expect(redirect, isNull);
      });
    });

    // ── 5. AUTH INITIAL / LOADING ──
    group('Auth Initial & Loading', () {
      final initialState = AuthInitial();

      test('Saat AuthInitial diarahkan ke /loading', () {
        final redirect = AppRouter.computeAuthRedirect(
          location: '/home',
          authState: initialState,
        );
        expect(redirect, '/loading');
      });

      test('Saat AuthInitial dan sudah di /loading tetap di /loading (return null)', () {
        final redirect = AppRouter.computeAuthRedirect(
          location: '/loading',
          authState: initialState,
        );
        expect(redirect, isNull);
      });
    });
  });
}
