import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/errors/failures.dart';
import 'package:rekber/features/admin/domain/repositories/admin_repository.dart';
import 'package:rekber/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:rekber/features/admin/presentation/cubit/admin_state.dart';

class MockAdminRepository extends Mock implements AdminRepository {}

void main() {
  late MockAdminRepository mockAdminRepository;
  late AdminCubit adminCubit;

  setUp(() {
    mockAdminRepository = MockAdminRepository();
    adminCubit = AdminCubit(adminRepository: mockAdminRepository);
  });

  tearDown(() {
    adminCubit.close();
  });

  group('AdminCubit - Metrics & Dashboard', () {
    final tMetrics = {
      'gmv': 50000000,
      'heldAmount': 20000000,
      'platformFeeRevenue': 1500000,
      'newUsers': 25,
      'openDisputes': 3,
      'pendingWithdrawals': 2,
      'transactionsByStatus': {
        'PENDING': 5,
        'PAID': 10,
        'COMPLETED': 50,
      },
    };

    blocTest<AdminCubit, AdminState>(
      'emits [AdminLoading, AdminDashboardLoaded] when getMetrics succeeds',
      build: () {
        when(() => mockAdminRepository.getMetrics())
            .thenAnswer((_) async => Right(tMetrics));
        return adminCubit;
      },
      act: (cubit) => cubit.loadDashboardMetrics(),
      expect: () => [
        const AdminLoading(message: 'Memuat data analitik...'),
        AdminDashboardLoaded(metrics: tMetrics),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'emits [AdminLoading, AdminError] when getMetrics fails',
      build: () {
        when(() => mockAdminRepository.getMetrics()).thenAnswer(
            (_) async => const Left(ServerFailure(message: 'Koneksi gagal')));
        return adminCubit;
      },
      act: (cubit) => cubit.loadDashboardMetrics(),
      expect: () => [
        const AdminLoading(message: 'Memuat data analitik...'),
        const AdminError(message: 'Koneksi gagal', isForbidden: false),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'emits [AdminLoading, AdminError(isForbidden: true)] when 403 Forbidden',
      build: () {
        when(() => mockAdminRepository.getMetrics()).thenAnswer((_) async =>
            const Left(ServerFailure(
                message:
                    'Akses ditolak: Hanya akun Administrator yang diizinkan.')));
        return adminCubit;
      },
      act: (cubit) => cubit.loadDashboardMetrics(),
      expect: () => [
        const AdminLoading(message: 'Memuat data analitik...'),
        const AdminError(
          message: 'Akses ditolak: Hanya akun Administrator yang diizinkan.',
          isForbidden: true,
        ),
      ],
    );
  });

  group('AdminCubit - Disputes', () {
    final tDisputes = [
      {'id': 'disp-1', 'reason': 'NOT_RECEIVED', 'status': 'OPEN'}
    ];

    blocTest<AdminCubit, AdminState>(
      'emits [AdminLoading, AdminDisputesLoaded] when loadDisputes succeeds',
      build: () {
        when(() => mockAdminRepository.getDisputes(
              status: any(named: 'status'),
              page: any(named: 'page'),
            )).thenAnswer((_) async => Right({'data': tDisputes}));
        return adminCubit;
      },
      act: (cubit) => cubit.loadDisputes(),
      expect: () => [
        const AdminLoading(message: 'Memuat daftar sengketa...'),
        AdminDisputesLoaded(disputes: tDisputes, statusFilter: 'Semua'),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'emits [AdminError] immediately if resolution note is less than 10 chars',
      build: () => adminCubit,
      act: (cubit) => cubit.resolveDispute(
        id: 'disp-1',
        decision: 'RELEASE_TO_SELLER',
        note: 'pendek',
      ),
      expect: () => [
        const AdminError(message: 'Catatan putusan minimal 10 karakter.'),
      ],
      verify: (_) {
        verifyNever(() => mockAdminRepository.resolveDispute(
              any(),
              decision: any(named: 'decision'),
              note: any(named: 'note'),
            ));
      },
    );

    blocTest<AdminCubit, AdminState>(
      'emits [AdminLoading, AdminActionSuccess, AdminLoading, AdminDisputesLoaded] when resolveDispute succeeds',
      build: () {
        when(() => mockAdminRepository.resolveDispute(
              'disp-1',
              decision: 'RELEASE_TO_SELLER',
              note: 'Catatan putusan yang sah dan lengkap',
            )).thenAnswer((_) async => const Right({'status': 'RESOLVED_SELLER'}));
        when(() => mockAdminRepository.getDisputes(
              status: any(named: 'status'),
              page: any(named: 'page'),
            )).thenAnswer((_) async => const Right({'data': []}));
        return adminCubit;
      },
      act: (cubit) => cubit.resolveDispute(
        id: 'disp-1',
        decision: 'RELEASE_TO_SELLER',
        note: 'Catatan putusan yang sah dan lengkap',
      ),
      expect: () => [
        const AdminLoading(message: 'Menyelesaikan sengketa...'),
        const AdminActionSuccess(
            message: 'Sengketa berhasil diputuskan & diselesaikan.'),
        const AdminLoading(message: 'Memuat daftar sengketa...'),
        const AdminDisputesLoaded(disputes: [], statusFilter: 'Semua'),
      ],
    );
  });

  group('AdminCubit - KYC', () {
    blocTest<AdminCubit, AdminState>(
      'emits [AdminLoading, AdminActionSuccess, AdminLoading, AdminKycLoaded] on approveKyc',
      build: () {
        when(() => mockAdminRepository.approveKyc('kyc-1'))
            .thenAnswer((_) async => const Right({'status': 'APPROVED'}));
        when(() => mockAdminRepository.getKycSubmissions(status: 'PENDING'))
            .thenAnswer((_) async => const Right({'data': []}));
        return adminCubit;
      },
      act: (cubit) => cubit.approveKyc('kyc-1'),
      expect: () => [
        const AdminLoading(message: 'Menyetujui KYC...'),
        const AdminActionSuccess(message: 'Pengajuan KYC berhasil disetujui.'),
        const AdminLoading(message: 'Memuat antrian KYC...'),
        const AdminKycLoaded(submissions: [], statusFilter: 'PENDING'),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'emits [AdminError] on rejectKyc if reason is less than 5 chars',
      build: () => adminCubit,
      act: (cubit) => cubit.rejectKyc(id: 'kyc-1', reason: 'bad'),
      expect: () => [
        const AdminError(message: 'Alasan penolakan minimal 5 karakter.'),
      ],
    );
  });

  group('AdminCubit - Users', () {
    blocTest<AdminCubit, AdminState>(
      'emits [AdminLoading, AdminActionSuccess, AdminLoading, AdminUsersLoaded] on banUser',
      build: () {
        when(() => mockAdminRepository.banUser('u-1', reason: 'Penipuan'))
            .thenAnswer((_) async => const Right({'isActive': false}));
        when(() => mockAdminRepository.getUsers())
            .thenAnswer((_) async => const Right({'data': []}));
        return adminCubit;
      },
      act: (cubit) => cubit.banUser('u-1', reason: 'Penipuan'),
      expect: () => [
        const AdminLoading(message: 'Memblokir pengguna...'),
        const AdminActionSuccess(message: 'Pengguna berhasil diblokir.'),
        const AdminLoading(message: 'Memuat data pengguna...'),
        const AdminUsersLoaded(users: [], searchQuery: ''),
      ],
    );
  });

  group('AdminCubit - Withdrawals', () {
    blocTest<AdminCubit, AdminState>(
      'emits [AdminLoading, AdminWithdrawalsLoaded] on loadWithdrawals',
      build: () {
        when(() => mockAdminRepository.getWithdrawals(status: 'PENDING_REVIEW'))
            .thenAnswer((_) async => const Right({'withdrawals': []}));
        return adminCubit;
      },
      act: (cubit) => cubit.loadWithdrawals(),
      expect: () => [
        const AdminLoading(message: 'Memuat permintaan penarikan...'),
        const AdminWithdrawalsLoaded(
          withdrawals: [],
          statusFilter: 'PENDING_REVIEW',
        ),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'emits [AdminLoading, AdminActionSuccess, ...] on approveWithdrawal',
      build: () {
        when(() => mockAdminRepository.approveWithdrawal('w-1'))
            .thenAnswer((_) async => const Right({'status': 'PROCESSING'}));
        when(() => mockAdminRepository.getWithdrawals(status: 'PENDING_REVIEW'))
            .thenAnswer((_) async => const Right({'withdrawals': []}));
        return adminCubit;
      },
      act: (cubit) => cubit.approveWithdrawal('w-1'),
      expect: () => [
        const AdminLoading(message: 'Menyetujui penarikan dana...'),
        const AdminActionSuccess(
            message: 'Penarikan dana disetujui & diproses ke penyedia.'),
        const AdminLoading(message: 'Memuat permintaan penarikan...'),
        const AdminWithdrawalsLoaded(
          withdrawals: [],
          statusFilter: 'PENDING_REVIEW',
        ),
      ],
    );
  });
}
