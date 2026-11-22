import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:rekber/core/errors/failures.dart';
import 'package:rekber/features/wallet/domain/entities/wallet_summary_entity.dart';
import 'package:rekber/features/wallet/domain/entities/bank_account_entity.dart';
import 'package:rekber/features/wallet/domain/entities/withdrawal_entity.dart';
import 'package:rekber/features/wallet/domain/entities/payment_intent_entity.dart';
import 'package:rekber/features/wallet/domain/entities/ledger_entry_entity.dart';
import 'package:rekber/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:rekber/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:rekber/features/wallet/presentation/cubit/wallet_state.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late MockWalletRepository mockRepository;
  late WalletCubit cubit;

  const tSummary = WalletSummaryEntity(balance: 500000, heldBalance: 100000);
  final tBankAccounts = [
    BankAccountEntity(
      id: 'bank-1',
      bankCode: 'BCA',
      accountLast4: '5678',
      accountName: 'Rizky',
      createdAt: DateTime.parse('2026-03-25T10:00:00Z'),
    ),
  ];
  final tWithdrawals = [
    WithdrawalEntity(
      id: 'wd-1',
      bankAccountId: 'bank-1',
      amount: 100000,
      fee: 0,
      status: 'PENDING_REVIEW',
      createdAt: DateTime.parse('2026-03-25T10:00:00Z'),
    ),
  ];
  final tLedger = [
    LedgerEntryEntity(
      id: 'led-1',
      amount: 50000,
      type: 'CREDIT',
      balanceAfter: 500000,
      createdAt: DateTime.parse('2026-03-25T10:00:00Z'),
    ),
  ];
  final tPaymentIntent = PaymentIntentEntity(
    id: 'top-1',
    provider: 'XENDIT',
    referenceId: 'TOP-123',
    amount: 100000,
    method: 'QRIS',
    status: 'PENDING',
    qrString: '00020101021226500016ID.CO.XENDIT',
    createdAt: DateTime.parse('2026-03-25T10:00:00Z'),
  );

  setUp(() {
    mockRepository = MockWalletRepository();
    cubit = WalletCubit(repository: mockRepository);
  });

  tearDown(() {
    cubit.close();
  });

  group('WalletCubit - loadWalletData', () {
    blocTest<WalletCubit, WalletState>(
      'memancarkan [WalletLoading, WalletLoaded] saat semua data dompet berhasil diambil',
      build: () {
        when(() => mockRepository.getWalletSummary())
            .thenAnswer((_) async => const Right(tSummary));
        when(() => mockRepository.getBankAccounts())
            .thenAnswer((_) async => Right(tBankAccounts));
        when(() => mockRepository.getWithdrawals())
            .thenAnswer((_) async => Right(tWithdrawals));
        when(() => mockRepository.getLedgerHistory(limit: any(named: 'limit')))
            .thenAnswer((_) async => Right(tLedger));
        return cubit;
      },
      act: (cubit) => cubit.loadWalletData(),
      expect: () => [
        WalletLoading(),
        WalletLoaded(
          summary: tSummary,
          bankAccounts: tBankAccounts,
          withdrawals: tWithdrawals,
          ledgerEntries: tLedger,
        ),
      ],
    );
  });

  group('WalletCubit - createTopUp', () {
    blocTest<WalletCubit, WalletState>(
      'memancarkan [WalletActionLoading, TopUpCreatedSuccess] saat sukses',
      build: () {
        when(() => mockRepository.createTopUp(
              amount: 100000,
              method: 'QRIS',
              bankCode: null,
            )).thenAnswer((_) async => Right(tPaymentIntent));
        return cubit;
      },
      act: (cubit) => cubit.createTopUp(amount: 100000, method: 'QRIS'),
      expect: () => [
        const WalletActionLoading(message: 'Membuat permintaan top-up...'),
        TopUpCreatedSuccess(paymentIntent: tPaymentIntent),
      ],
    );
  });

  group('WalletCubit - submitWithdrawal with KYC detection', () {
    blocTest<WalletCubit, WalletState>(
      'memancarkan [WalletActionLoading, WalletActionSuccess, WalletLoading, WalletLoaded] saat penarikan sukses',
      build: () {
        when(() => mockRepository.requestWithdrawal(
              bankAccountId: 'bank-1',
              amount: 50000,
              idempotencyKey: any(named: 'idempotencyKey'),
            )).thenAnswer((_) async => Right(tWithdrawals.first));
        when(() => mockRepository.getWalletSummary())
            .thenAnswer((_) async => const Right(tSummary));
        when(() => mockRepository.getBankAccounts())
            .thenAnswer((_) async => Right(tBankAccounts));
        when(() => mockRepository.getWithdrawals())
            .thenAnswer((_) async => Right(tWithdrawals));
        when(() => mockRepository.getLedgerHistory(limit: any(named: 'limit')))
            .thenAnswer((_) async => Right(tLedger));
        return cubit;
      },
      act: (cubit) => cubit.submitWithdrawal(bankAccountId: 'bank-1', amount: 50000),
      expect: () => [
        const WalletActionLoading(message: 'Mengajukan penarikan dana...'),
        const WalletActionSuccess(message: 'Permintaan penarikan berhasil diajukan!'),
        WalletLoading(),
        WalletLoaded(
          summary: tSummary,
          bankAccounts: tBankAccounts,
          withdrawals: tWithdrawals,
          ledgerEntries: tLedger,
        ),
      ],
    );

    blocTest<WalletCubit, WalletState>(
      'memancarkan [WalletActionLoading, WalletActionFailure(isKycRequired: true)] saat ditolak karena KYC',
      build: () {
        when(() => mockRepository.requestWithdrawal(
              bankAccountId: 'bank-1',
              amount: 50000,
              idempotencyKey: any(named: 'idempotencyKey'),
            )).thenAnswer((_) async => const Left(ServerFailure(
              message: 'Penarikan dana mensyaratkan akun dengan status KYC APPROVED.',
              statusCode: 403,
            )));
        return cubit;
      },
      act: (cubit) => cubit.submitWithdrawal(bankAccountId: 'bank-1', amount: 50000),
      expect: () => [
        const WalletActionLoading(message: 'Mengajukan penarikan dana...'),
        const WalletActionFailure(
          message: 'Penarikan dana mensyaratkan akun dengan status KYC APPROVED.',
          isKycRequired: true,
        ),
      ],
    );
  });
}
