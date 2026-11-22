import 'package:flutter_test/flutter_test.dart';
import 'package:rekber/config/routes/app_router.dart';
import 'package:rekber/features/auth/domain/entities/user_entity.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_state.dart';

void main() {
  group('Admin Route Guard - Role-Based Access Control', () {
    final now = DateTime(2026, 1, 1);

    final userRoleUser = UserEntity(
      id: 'user-normal-1',
      email: 'user@example.com',
      fullName: 'Pengguna Biasa',
      role: 'USER',
      kycStatus: 'NONE',
      isActive: true,
      createdAt: now,
    );

    final userRoleAdmin = UserEntity(
      id: 'admin-1',
      email: 'admin@rekber.id',
      fullName: 'Super Administrator',
      role: 'ADMIN',
      kycStatus: 'APPROVED',
      isActive: true,
      createdAt: now,
    );

    test('blocks regular USER role from accessing /admin/* and redirects to /home', () {
      final authState = AuthAuthenticated(user: userRoleUser, activeRole: 'buyer');

      // Attempting to access dashboard admin
      final redirectDashboard = AppRouter.computeAuthRedirect(
        location: '/admin/dashboard',
        authState: authState,
      );
      expect(redirectDashboard, equals('/home'));

      // Attempting to access dispute moderation
      final redirectDispute = AppRouter.computeAuthRedirect(
        location: '/admin/dispute',
        authState: authState,
      );
      expect(redirectDispute, equals('/home'));

      // Attempting to access KYC approval
      final redirectKyc = AppRouter.computeAuthRedirect(
        location: '/admin/kyc',
        authState: authState,
      );
      expect(redirectKyc, equals('/home'));

      // Attempting to access withdrawals approval
      final redirectWithdrawals = AppRouter.computeAuthRedirect(
        location: '/admin/withdrawals',
        authState: authState,
      );
      expect(redirectWithdrawals, equals('/home'));
    });

    test('allows ADMIN role to access /admin/* (returns null redirect)', () {
      final authState = AuthAuthenticated(user: userRoleAdmin, activeRole: 'admin');

      expect(
        AppRouter.computeAuthRedirect(
          location: '/admin/dashboard',
          authState: authState,
        ),
        isNull,
      );

      expect(
        AppRouter.computeAuthRedirect(
          location: '/admin/dispute',
          authState: authState,
        ),
        isNull,
      );

      expect(
        AppRouter.computeAuthRedirect(
          location: '/admin/kyc',
          authState: authState,
        ),
        isNull,
      );

      expect(
        AppRouter.computeAuthRedirect(
          location: '/admin/withdrawals',
          authState: authState,
        ),
        isNull,
      );
    });

    test('redirects ADMIN to /admin/dashboard when visiting auth screen (/login)', () {
      final authState = AuthAuthenticated(user: userRoleAdmin, activeRole: 'admin');

      final redirect = AppRouter.computeAuthRedirect(
        location: '/login',
        authState: authState,
      );
      expect(redirect, equals('/admin/dashboard'));
    });

    test('redirects unauthenticated user accessing /admin/* to /login', () {
      final authState = AuthUnauthenticated();

      final redirect = AppRouter.computeAuthRedirect(
        location: '/admin/dashboard',
        authState: authState,
      );
      expect(redirect, equals('/login'));
    });
  });
}
