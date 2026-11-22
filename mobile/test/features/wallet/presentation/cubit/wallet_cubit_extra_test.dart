import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/errors/failures.dart';
import 'package:rekber/features/wallet/domain/entities/bank_account_entity.dart';
import 'package:rekber/features/wallet/domain/entities/payment_intent_entity.dart';
import 'package:rekber/features/wallet/domain/entities/withdrawal_entity.dart';
import 'package:rekber/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:rekber/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:rekber/features/wallet/presentation/cubit/wallet_state.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late MockWalletRepository mockRepository;
  late WalletCubit cubit;

  final tIntent = PaymentIntentEntity(
    id: 'pi-1',
    provider: 'XENDIT',
    referenceId: 'TOPUP-101',
    amount: 50000,
    method: 'QRIS',
    status: 'PENDING',
    qrString: '00020101021226590014ID.LINKAJA.WWW',
    expiresAt: DateTime(2026, 5, 10),
    createdAt: DateTime(2026, 5, 9),
  );

  final tBank = BankAccountEntity(
    id: 'ba-1',
    bankCode: 'BCA',
    accountLast4: '8890',
    accountName: 'Budi Santoso',
    isDefault: true,
    createdAt: DateTime(2026, 5, 1),
  );

  final tWithdrawal = WithdrawalEntity(
    id: 'w-1',
    bankAccountId: 'ba-1',
    amount: 100000,
    fee: 2500,
    status: 'PENDING_REVIEW',
    createdAt: DateTime(2026, 5, 1),
  );

  setUp(() {
    mockRepository = MockWalletRepository();
    cubit = WalletCubit(repository: mockRepository);
  });

  tearDown(() {
    cubit.close();
  });

  group('WalletCubit - Extra Flows', () {
    blocTest<WalletCubit, WalletState>(
      'createTopUp emits TopUpCreatedSuccess on success',
      build: () {
        when(() => mockRepository.createTopUp(
              amount: 50000,
              method: 'QRIS',
              bankCode: null,
            )).thenAnswer((_) async => Right(tIntent));
        return cubit;
      },
      act: (c) => c.createTopUp(amount: 50000, method: 'QRIS'),
      expect: () => [
        const WalletActionLoading(message: 'Membuat permintaan top-up...'),
        TopUpCreatedSuccess(paymentIntent: tIntent),
      ],
    );

    blocTest<WalletCubit, WalletState>(
      'addBankAccount emits BankAccountActionSuccess on success',
      build: () {
        when(() => mockRepository.createBankAccount(
              bankCode: 'BCA',
              accountNumber: '1234567890',
              accountName: 'Budi Santoso',
            )).thenAnswer((_) async => Right(tBank));
        when(() => mockRepository.getWalletSummary()).thenAnswer(
            (_) async => const Left(ServerFailure(message: 'err')));
        when(() => mockRepository.getBankAccounts())
            .thenAnswer((_) async => Right([tBank]));
        when(() => mockRepository.getWithdrawals())
            .thenAnswer((_) async => const Right([]));
        when(() => mockRepository.getLedgerHistory(limit: any(named: 'limit')))
            .thenAnswer((_) async => const Right([]));
        return cubit;
      },
      act: (c) => c.addBankAccount(
        bankCode: 'BCA',
        accountNumber: '1234567890',
        accountName: 'Budi Santoso',
      ),
      expect: () => [
        const WalletActionLoading(message: 'Menyimpan rekening bank...'),
        const WalletActionSuccess(message: 'Rekening bank berhasil disimpan.'),
        WalletLoading(),
        isA<WalletLoaded>(),
      ],
    );

    blocTest<WalletCubit, WalletState>(
      'submitWithdrawal emits WalletActionSuccess on success',
      build: () {
        when(() => mockRepository.requestWithdrawal(
              bankAccountId: 'ba-1',
              amount: 100000,
              idempotencyKey: any(named: 'idempotencyKey'),
            )).thenAnswer((_) async => Right(tWithdrawal));
        when(() => mockRepository.getWalletSummary()).thenAnswer(
            (_) async => const Left(ServerFailure(message: 'err')));
        when(() => mockRepository.getBankAccounts())
            .thenAnswer((_) async => const Right([]));
        when(() => mockRepository.getWithdrawals())
            .thenAnswer((_) async => Right([tWithdrawal]));
        when(() => mockRepository.getLedgerHistory(limit: any(named: 'limit')))
            .thenAnswer((_) async => const Right([]));
        return cubit;
      },
      act: (c) => c.submitWithdrawal(bankAccountId: 'ba-1', amount: 100000),
      expect: () => [
        const WalletActionLoading(message: 'Mengajukan penarikan dana...'),
        const WalletActionSuccess(
            message: 'Permintaan penarikan berhasil diajukan!'),
        WalletLoading(),
        isA<WalletLoaded>(),
      ],
    );
  });
}
