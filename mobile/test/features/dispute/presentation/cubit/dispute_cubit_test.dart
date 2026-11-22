import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/errors/failures.dart';
import 'package:rekber/features/dispute/domain/entities/dispute_entity.dart';
import 'package:rekber/features/dispute/domain/repositories/dispute_repository.dart';
import 'package:rekber/features/dispute/presentation/cubit/dispute_cubit.dart';
import 'package:rekber/features/dispute/presentation/cubit/dispute_state.dart';

class MockDisputeRepository extends Mock implements DisputeRepository {}

void main() {
  late MockDisputeRepository mockDisputeRepository;
  late DisputeCubit disputeCubit;

  final tDispute = DisputeEntity(
    id: 'disp-1',
    transactionId: 'tx-1',
    openedById: 'user-buyer',
    reason: 'NOT_RECEIVED',
    description: 'Barang tidak kunjung sampai.',
    status: 'OPEN',
    createdAt: DateTime(2026, 5, 10),
  );

  final tEvidence = DisputeEvidenceEntity(
    id: 'ev-1',
    disputeId: 'disp-1',
    submittedById: 'user-buyer',
    note: 'Bukti resi dan video unboxing',
    fileIds: ['file-1'],
    createdAt: DateTime(2026, 5, 10),
  );

  setUp(() {
    mockDisputeRepository = MockDisputeRepository();
    disputeCubit = DisputeCubit(repository: mockDisputeRepository);
  });

  tearDown(() {
    disputeCubit.close();
  });

  group('DisputeCubit Unit Tests', () {
    blocTest<DisputeCubit, DisputeState>(
      'emits [DisputeLoading, DisputeLoaded] when loadDisputeById succeeds',
      build: () {
        when(() => mockDisputeRepository.getDisputeById('disp-1'))
            .thenAnswer((_) async => Right(tDispute));
        return disputeCubit;
      },
      act: (cubit) => cubit.loadDisputeById('disp-1'),
      expect: () => [
        DisputeLoading(),
        DisputeLoaded(dispute: tDispute),
      ],
    );

    blocTest<DisputeCubit, DisputeState>(
      'emits [DisputeLoading, DisputeError] when loadDisputeById fails',
      build: () {
        when(() => mockDisputeRepository.getDisputeById('disp-1')).thenAnswer(
            (_) async => const Left(ServerFailure(message: 'Tidak ditemukan')));
        return disputeCubit;
      },
      act: (cubit) => cubit.loadDisputeById('disp-1'),
      expect: () => [
        DisputeLoading(),
        const DisputeError(message: 'Tidak ditemukan'),
      ],
    );

    blocTest<DisputeCubit, DisputeState>(
      'emits [DisputeActionLoading, DisputeActionSuccess] on openDispute success',
      build: () {
        when(() => mockDisputeRepository.openDispute(
              transactionId: 'tx-1',
              reason: 'NOT_RECEIVED',
              description: 'Deskripsi panjang lebih dari 20 karakter',
              fileIds: null,
            )).thenAnswer((_) async => Right(tDispute));
        return disputeCubit;
      },
      act: (cubit) => cubit.openDispute(
        transactionId: 'tx-1',
        reason: 'NOT_RECEIVED',
        description: 'Deskripsi panjang lebih dari 20 karakter',
      ),
      expect: () => [
        const DisputeActionLoading(message: 'Mengajukan sengketa...'),
        DisputeActionSuccess(
          message: 'Sengketa berhasil diajukan.',
          dispute: tDispute,
        ),
      ],
    );

    blocTest<DisputeCubit, DisputeState>(
      'emits [DisputeActionLoading, DisputeActionSuccess] on submitEvidence success',
      build: () {
        when(() => mockDisputeRepository.submitEvidence(
              disputeId: 'disp-1',
              note: 'Bukti resi dan video unboxing',
              fileIds: ['file-1'],
            )).thenAnswer((_) async => Right(tEvidence));
        when(() => mockDisputeRepository.getDisputeById('disp-1'))
            .thenAnswer((_) async => Right(tDispute));
        return disputeCubit;
      },
      act: (cubit) => cubit.submitEvidence(
        disputeId: 'disp-1',
        note: 'Bukti resi dan video unboxing',
        fileIds: ['file-1'],
      ),
      expect: () => [
        const DisputeActionLoading(message: 'Mengunggah bukti...'),
        const DisputeActionSuccess(
            message: 'Bukti sengketa berhasil ditambahkan.'),
        DisputeLoading(),
        DisputeLoaded(dispute: tDispute),
      ],
    );
  });
}
