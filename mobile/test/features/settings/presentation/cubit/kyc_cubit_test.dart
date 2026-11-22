import 'dart:io';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/features/settings/domain/repositories/kyc_repository.dart';
import 'package:rekber/features/settings/presentation/cubit/kyc_cubit.dart';
import 'package:rekber/features/settings/presentation/cubit/kyc_state.dart';

class MockKycRepository extends Mock implements KycRepository {}

void main() {
  late MockKycRepository mockKycRepository;
  late KycCubit kycCubit;

  setUpAll(() {
    registerFallbackValue(File('dummy.jpg'));
  });

  setUp(() {
    mockKycRepository = MockKycRepository();
    kycCubit = KycCubit(kycRepository: mockKycRepository);
  });

  tearDown(() {
    kycCubit.close();
  });

  group('KycCubit - Status Flow', () {
    blocTest<KycCubit, KycState>(
      'emits [KycLoading, KycLoaded(NONE)] when no submission exists',
      build: () {
        when(() => mockKycRepository.getMyKyc()).thenAnswer(
            (_) async => const Right({'kycStatus': 'NONE', 'submission': null}));
        return kycCubit;
      },
      act: (cubit) => cubit.fetchKycStatus(),
      expect: () => [
        const KycLoading(),
        const KycLoaded(status: 'NONE'),
      ],
    );

    blocTest<KycCubit, KycState>(
      'emits [KycLoading, KycLoaded(PENDING)] when submission is under review',
      build: () {
        when(() => mockKycRepository.getMyKyc()).thenAnswer((_) async => const Right({
              'kycStatus': 'PENDING',
              'submission': {
                'status': 'PENDING',
                'fullName': 'Budi Santoso',
                'nikMasked': '3201••••••••1234',
              }
            }));
        return kycCubit;
      },
      act: (cubit) => cubit.fetchKycStatus(),
      expect: () => [
        const KycLoading(),
        const KycLoaded(
          status: 'PENDING',
          fullName: 'Budi Santoso',
          nikMasked: '3201••••••••1234',
        ),
      ],
    );

    blocTest<KycCubit, KycState>(
      'emits [KycLoading, KycLoaded(APPROVED)] when verified',
      build: () {
        when(() => mockKycRepository.getMyKyc()).thenAnswer((_) async => const Right({
              'kycStatus': 'APPROVED',
              'submission': {
                'status': 'APPROVED',
                'fullName': 'Budi Santoso',
                'nikMasked': '3201••••••••1234',
              }
            }));
        return kycCubit;
      },
      act: (cubit) => cubit.fetchKycStatus(),
      expect: () => [
        const KycLoading(),
        const KycLoaded(
          status: 'APPROVED',
          fullName: 'Budi Santoso',
          nikMasked: '3201••••••••1234',
        ),
      ],
    );

    blocTest<KycCubit, KycState>(
      'emits [KycLoading, KycLoaded(REJECTED)] with rejection reason',
      build: () {
        when(() => mockKycRepository.getMyKyc()).thenAnswer((_) async => const Right({
              'kycStatus': 'REJECTED',
              'submission': {
                'status': 'REJECTED',
                'fullName': 'Budi Santoso',
                'nikMasked': '3201••••••••1234',
                'rejectionReason': 'Foto e-KTP tidak terbaca jelas.',
              }
            }));
        return kycCubit;
      },
      act: (cubit) => cubit.fetchKycStatus(),
      expect: () => [
        const KycLoading(),
        const KycLoaded(
          status: 'REJECTED',
          fullName: 'Budi Santoso',
          nikMasked: '3201••••••••1234',
          rejectionReason: 'Foto e-KTP tidak terbaca jelas.',
        ),
      ],
    );
  });

  group('KycCubit - Submission & NIK Validation', () {
    final tKtp = File('ktp.jpg');
    final tSelfie = File('selfie.jpg');

    blocTest<KycCubit, KycState>(
      'emits [KycFailure] if NIK is not 16 digits (e.g. 15 digits)',
      build: () => kycCubit,
      act: (cubit) => cubit.submitKyc(
        fullName: 'Budi Santoso',
        nik: '123456789012345', // 15 digits
        idCardFile: tKtp,
        selfieFile: tSelfie,
      ),
      expect: () => [
        const KycFailure(message: 'NIK harus terdiri dari tepat 16 digit angka.'),
      ],
      verify: (_) {
        verifyNever(() => mockKycRepository.uploadKycFile(any(), any()));
      },
    );

    blocTest<KycCubit, KycState>(
      'emits [KycFailure] if NIK contains non-numeric characters',
      build: () => kycCubit,
      act: (cubit) => cubit.submitKyc(
        fullName: 'Budi Santoso',
        nik: '123456789012345A', // contains letter
        idCardFile: tKtp,
        selfieFile: tSelfie,
      ),
      expect: () => [
        const KycFailure(message: 'NIK harus terdiri dari tepat 16 digit angka.'),
      ],
      verify: (_) {
        verifyNever(() => mockKycRepository.uploadKycFile(any(), any()));
      },
    );

    blocTest<KycCubit, KycState>(
      'uploads files and submits KYC successfully when data is valid',
      build: () {
        when(() => mockKycRepository.uploadKycFile(tKtp, 'KYC_ID'))
            .thenAnswer((_) async => const Right('file-ktp-1'));
        when(() => mockKycRepository.uploadKycFile(tSelfie, 'KYC_SELFIE'))
            .thenAnswer((_) async => const Right('file-selfie-1'));
        when(() => mockKycRepository.submitKyc(
              fullName: 'Budi Santoso',
              nik: '3201123456780001',
              idFileId: 'file-ktp-1',
              selfieFileId: 'file-selfie-1',
            )).thenAnswer((_) async => const Right({'status': 'PENDING'}));
        when(() => mockKycRepository.getMyKyc()).thenAnswer((_) async => const Right({
              'kycStatus': 'PENDING',
              'submission': {
                'status': 'PENDING',
                'fullName': 'Budi Santoso',
                'nikMasked': '3201••••••••0001',
              }
            }));
        return kycCubit;
      },
      act: (cubit) => cubit.submitKyc(
        fullName: 'Budi Santoso',
        nik: '3201123456780001',
        idCardFile: tKtp,
        selfieFile: tSelfie,
      ),
      expect: () => [
        const KycSubmitting(step: 'Mengunggah foto KTP...'),
        const KycSubmitting(step: 'Mengunggah foto selfie...'),
        const KycSubmitting(step: 'Mengirim permohonan verifikasi...'),
        const KycSubmitSuccess(
          message: 'Permohonan verifikasi identitas (KYC) berhasil dikirim.',
        ),
        const KycLoading(),
        const KycLoaded(
          status: 'PENDING',
          fullName: 'Budi Santoso',
          nikMasked: '3201••••••••0001',
        ),
      ],
    );
  });
}
