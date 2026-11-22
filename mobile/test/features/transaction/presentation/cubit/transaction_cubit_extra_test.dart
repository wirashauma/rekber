import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/features/transaction/data/models/public_config_model.dart';
import 'package:rekber/features/transaction/domain/entities/transaction_entity.dart';
import 'package:rekber/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:rekber/features/transaction/presentation/cubit/transaction_cubit.dart';
import 'package:rekber/features/transaction/presentation/cubit/transaction_state.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionRepository mockRepository;
  late TransactionCubit cubit;

  final tTx = TransactionEntity(
    id: 'tx-1',
    txCode: 'TRX-101',
    buyerId: 'user-buyer',
    sellerId: 'user-seller',
    amount: 100000,
    platformFee: 2000,
    buyerFee: 2000,
    sellerFee: 0,
    feePayer: 'BUYER',
    description: 'Akun Game',
    status: 'PAID',
    createdAt: DateTime(2026, 5, 1),
  );

  setUp(() {
    mockRepository = MockTransactionRepository();
    cubit = TransactionCubit(repository: mockRepository);
  });

  tearDown(() {
    cubit.close();
  });

  group('TransactionCubit - Extra Flows', () {
    test('loadPublicConfig updates publicConfig property', () async {
      const tConfig = PublicConfigModel(
        feePercent: 2.0,
        feeMin: 5000,
        feePayerDefault: 'BUYER',
        withdrawMin: 50000,
        withdrawFee: 2500,
        maxTransactionAmount: 50000000,
      );
      when(() => mockRepository.getPublicConfig())
          .thenAnswer((_) async => const Right(tConfig));

      final result = await cubit.loadPublicConfig();
      expect(result, equals(tConfig));
      expect(cubit.publicConfig, equals(tConfig));
    });

    blocTest<TransactionCubit, TransactionState>(
      'loadTransactionDetail succeeds',
      build: () {
        when(() => mockRepository.getTransactionById('tx-1'))
            .thenAnswer((_) async => Right(tTx));
        return cubit;
      },
      act: (c) => c.loadTransactionDetail('tx-1'),
      expect: () => [
        TransactionLoading(),
        TransactionDetailLoaded(transaction: tTx),
      ],
    );

    blocTest<TransactionCubit, TransactionState>(
      'createTransaction succeeds and sets currentDetail',
      build: () {
        when(() => mockRepository.createTransaction(
              amount: 100000,
              itemDescription: 'Akun Game',
              feePayer: 'BUYER',
            )).thenAnswer((_) async => Right(tTx));
        return cubit;
      },
      act: (c) => c.createTransaction(
        amount: 100000,
        itemDescription: 'Akun Game',
        feePayer: 'BUYER',
      ),
      expect: () => [
        const TransactionActionLoading(message: 'Membuat transaksi...'),
        TransactionActionSuccess(
          message: 'Transaksi berhasil dibuat.',
          transaction: tTx,
        ),
      ],
    );

    blocTest<TransactionCubit, TransactionState>(
      'submitShipment succeeds',
      build: () {
        when(() => mockRepository.uploadShipmentProof(any()))
            .thenAnswer((_) async => const Right('file-proof-1'));
        when(() => mockRepository.submitShipment(
              id: 'tx-1',
              trackingNumber: 'JNE123',
              courier: 'JNE',
              fileIds: ['file-proof-1'],
              note: 'Sudah dikirim',
            )).thenAnswer((_) async => Right(tTx));
        return cubit;
      },
      act: (c) => c.submitShipment(
        id: 'tx-1',
        trackingNumber: 'JNE123',
        courier: 'JNE',
        proofFilePath: 'dummy_path/proof.png',
        note: 'Sudah dikirim',
      ),
      expect: () => [
        const TransactionActionLoading(message: 'Mengunggah bukti pengiriman...'),
        const TransactionActionLoading(message: 'Menyimpan bukti pengiriman...'),
        TransactionActionSuccess(
          message: 'Pesanan ditandai telah dikirim!',
          transaction: tTx,
        ),
      ],
    );
  });
}
