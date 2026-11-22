import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:rekber/core/errors/failures.dart';
import 'package:rekber/features/transaction/domain/entities/transaction_entity.dart';
import 'package:rekber/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:rekber/features/transaction/presentation/cubit/transaction_cubit.dart';
import 'package:rekber/features/transaction/presentation/cubit/transaction_state.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionRepository mockRepository;
  late TransactionCubit cubit;

  final tTransaction = TransactionEntity(
    id: 'tx-123',
    txCode: 'TRX-TEST01',
    buyerId: 'user-buyer',
    sellerId: 'user-seller',
    amount: 100000,
    platformFee: 2000,
    buyerFee: 1000,
    sellerFee: 1000,
    feePayer: 'SPLIT',
    status: 'PENDING',
    description: 'Test Item',
    createdAt: DateTime.parse('2026-03-25T10:00:00Z'),
  );

  final tPaidTransaction = TransactionEntity(
    id: 'tx-123',
    txCode: 'TRX-TEST01',
    buyerId: 'user-buyer',
    sellerId: 'user-seller',
    amount: 100000,
    platformFee: 2000,
    buyerFee: 1000,
    sellerFee: 1000,
    feePayer: 'SPLIT',
    status: 'PAID',
    description: 'Test Item',
    createdAt: DateTime.parse('2026-03-25T10:00:00Z'),
  );

  setUp(() {
    mockRepository = MockTransactionRepository();
    cubit = TransactionCubit(repository: mockRepository);
  });

  tearDown(() {
    cubit.close();
  });

  group('TransactionCubit - loadTransactions', () {
    blocTest<TransactionCubit, TransactionState>(
      'memancarkan [TransactionLoading, TransactionListLoaded] saat sukses',
      build: () {
        when(() => mockRepository.getTransactions())
            .thenAnswer((_) async => Right([tTransaction]));
        return cubit;
      },
      act: (cubit) => cubit.loadTransactions(),
      expect: () => [
        TransactionLoading(),
        TransactionListLoaded(transactions: [tTransaction]),
      ],
    );

    blocTest<TransactionCubit, TransactionState>(
      'memancarkan [TransactionLoading, TransactionError] saat gagal',
      build: () {
        when(() => mockRepository.getTransactions())
            .thenAnswer((_) async => const Left(ServerFailure(message: 'Server error', statusCode: 500)));
        return cubit;
      },
      act: (cubit) => cubit.loadTransactions(),
      expect: () => [
        TransactionLoading(),
        const TransactionError(message: 'Server error'),
      ],
    );
  });

  group('TransactionCubit - payFromBalance', () {
    blocTest<TransactionCubit, TransactionState>(
      'memancarkan [TransactionActionLoading, TransactionActionSuccess] saat pembayaran berhasil',
      build: () {
        when(() => mockRepository.updateStatus(id: 'tx-123', status: 'PAID'))
            .thenAnswer((_) async => Right(tPaidTransaction));
        return cubit;
      },
      act: (cubit) => cubit.payFromBalance('tx-123'),
      expect: () => [
        const TransactionActionLoading(message: 'Memproses pembayaran...'),
        TransactionActionSuccess(
          message: 'Pembayaran berhasil dilakukan!',
          transaction: tPaidTransaction,
        ),
      ],
    );

    blocTest<TransactionCubit, TransactionState>(
      'memancarkan [TransactionActionLoading, TransactionActionFailure(isConflict: false)] saat gagal umum',
      build: () {
        when(() => mockRepository.updateStatus(id: 'tx-123', status: 'PAID'))
            .thenAnswer((_) async => const Left(ServerFailure(message: 'Saldo tidak cukup', statusCode: 400)));
        return cubit;
      },
      act: (cubit) => cubit.payFromBalance('tx-123'),
      expect: () => [
        const TransactionActionLoading(message: 'Memproses pembayaran...'),
        const TransactionActionFailure(message: 'Saldo tidak cukup', isConflict: false),
      ],
    );

    blocTest<TransactionCubit, TransactionState>(
      'memancarkan [TransactionActionLoading, TransactionActionFailure(isConflict: true), TransactionLoading, TransactionDetailLoaded] saat terjadi 409 Conflict',
      build: () {
        when(() => mockRepository.updateStatus(id: 'tx-123', status: 'PAID'))
            .thenAnswer((_) async => const Left(ConflictFailure(message: 'Transaksi sudah dibayar atau dibatalkan')));
        when(() => mockRepository.getTransactionById('tx-123'))
            .thenAnswer((_) async => Right(tPaidTransaction));
        return cubit;
      },
      act: (cubit) => cubit.payFromBalance('tx-123'),
      expect: () => [
        const TransactionActionLoading(message: 'Memproses pembayaran...'),
        const TransactionActionFailure(
          message: 'Transaksi sudah dibayar atau dibatalkan',
          isConflict: true,
        ),
        TransactionLoading(),
        TransactionDetailLoaded(transaction: tPaidTransaction),
      ],
    );
  });

  group('TransactionCubit - confirmReceived & cancelTransaction', () {
    blocTest<TransactionCubit, TransactionState>(
      'confirmReceived memancarkan success',
      build: () {
        when(() => mockRepository.updateStatus(id: 'tx-123', status: 'COMPLETED'))
            .thenAnswer((_) async => Right(tTransaction));
        return cubit;
      },
      act: (cubit) => cubit.confirmReceived('tx-123'),
      expect: () => [
        const TransactionActionLoading(message: 'Mengonfirmasi pesanan...'),
        TransactionActionSuccess(
          message: 'Transaksi selesai. Dana telah dilepas ke penjual.',
          transaction: tTransaction,
        ),
      ],
    );

    blocTest<TransactionCubit, TransactionState>(
      'cancelTransaction memancarkan success',
      build: () {
        when(() => mockRepository.updateStatus(id: 'tx-123', status: 'CANCELLED'))
            .thenAnswer((_) async => Right(tTransaction));
        return cubit;
      },
      act: (cubit) => cubit.cancelTransaction('tx-123'),
      expect: () => [
        const TransactionActionLoading(message: 'Membatalkan transaksi...'),
        TransactionActionSuccess(
          message: 'Transaksi berhasil dibatalkan.',
          transaction: tTransaction,
        ),
      ],
    );
  });
}
