import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/features/admin/domain/repositories/admin_repository.dart';
import 'package:rekber/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:rekber/features/admin/presentation/cubit/admin_state.dart';

class MockAdminRepository extends Mock implements AdminRepository {}

void main() {
  late MockAdminRepository mockRepository;
  late AdminCubit cubit;

  setUp(() {
    mockRepository = MockAdminRepository();
    cubit = AdminCubit(adminRepository: mockRepository);
  });

  tearDown(() {
    cubit.close();
  });

  group('AdminCubit - Additional Flows', () {
    blocTest<AdminCubit, AdminState>(
      'loadSettings and updateSetting',
      build: () {
        when(() => mockRepository.getSettings())
            .thenAnswer((_) async => const Right({'fee_percent': '2.0'}));
        when(() => mockRepository.updateSetting('fee_percent', '2.5'))
            .thenAnswer((_) async => const Right({'fee_percent': '2.5'}));
        return cubit;
      },
      act: (c) async {
        await c.loadSettings();
        await c.updateSetting('fee_percent', '2.5');
      },
      expect: () => [
        const AdminLoading(message: 'Memuat pengaturan...'),
        const AdminSettingsLoaded(settings: {'fee_percent': '2.0'}),
        const AdminLoading(message: 'Menyimpan pengaturan...'),
        const AdminActionSuccess(message: 'Pengaturan fee_percent berhasil diperbarui.'),
        const AdminLoading(message: 'Memuat pengaturan...'),
        const AdminSettingsLoaded(settings: {'fee_percent': '2.0'}),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'loadAuditLogs succeeds',
      build: () {
        when(() => mockRepository.getAuditLogs()).thenAnswer((_) async => const Right({
              'data': [
                {'action': 'WITHDRAWAL_APPROVE'}
              ]
            }));
        return cubit;
      },
      act: (c) => c.loadAuditLogs(),
      expect: () => [
        const AdminLoading(message: 'Memuat log audit...'),
        const AdminAuditLogsLoaded(
          logs: [
            {'action': 'WITHDRAWAL_APPROVE'}
          ],
        ),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'unbanUser succeeds',
      build: () {
        when(() => mockRepository.unbanUser('u-1'))
            .thenAnswer((_) async => const Right({'isActive': true}));
        when(() => mockRepository.getUsers())
            .thenAnswer((_) async => const Right({'data': []}));
        return cubit;
      },
      act: (c) => c.unbanUser('u-1'),
      expect: () => [
        const AdminLoading(message: 'Membuka blokir pengguna...'),
        const AdminActionSuccess(message: 'Blokir pengguna berhasil dibuka.'),
        const AdminLoading(message: 'Memuat data pengguna...'),
        const AdminUsersLoaded(users: [], searchQuery: ''),
      ],
    );

    blocTest<AdminCubit, AdminState>(
      'rejectWithdrawal succeeds when reason >= 5 chars',
      build: () {
        when(() => mockRepository.rejectWithdrawal('w-1', reason: 'Alasan valid'))
            .thenAnswer((_) async => const Right({'status': 'REJECTED'}));
        when(() => mockRepository.getWithdrawals(status: 'PENDING_REVIEW'))
            .thenAnswer((_) async => const Right({'withdrawals': []}));
        return cubit;
      },
      act: (c) => c.rejectWithdrawal(id: 'w-1', reason: 'Alasan valid'),
      expect: () => [
        const AdminLoading(message: 'Menolak permintaan penarikan...'),
        const AdminActionSuccess(
            message: 'Permintaan penarikan berhasil ditolak & saldo dikembalikan.'),
        const AdminLoading(message: 'Memuat permintaan penarikan...'),
        const AdminWithdrawalsLoaded(
          withdrawals: [],
          statusFilter: 'PENDING_REVIEW',
        ),
      ],
    );
  });
}
