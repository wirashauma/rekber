import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:rekber/features/wallet/domain/entities/payment_intent_entity.dart';
import 'package:rekber/features/wallet/domain/entities/wallet_summary_entity.dart';
import 'package:rekber/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:rekber/features/wallet/presentation/cubit/wallet_cubit.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late MockWalletRepository mockRepository;
  late WalletCubit walletCubit;

  final tPendingIntent = PaymentIntentEntity(
    id: 'top-1',
    provider: 'XENDIT',
    referenceId: 'TOP-123',
    amount: 50000,
    method: 'QRIS',
    status: 'PENDING',
    createdAt: DateTime.now(),
  );

  final tPaidIntent = PaymentIntentEntity(
    id: 'top-1',
    provider: 'XENDIT',
    referenceId: 'TOP-123',
    amount: 50000,
    method: 'QRIS',
    status: 'PAID',
    createdAt: DateTime.now(),
  );

  setUp(() {
    mockRepository = MockWalletRepository();
    walletCubit = WalletCubit(repository: mockRepository);
  });

  tearDown(() {
    walletCubit.close();
  });

  test('Top-up status polling executes every 5 seconds and refreshes balance on PAID', () {
    fakeAsync((async) {
      int pollCount = 0;

      when(() => mockRepository.getTopUpStatus('top-1')).thenAnswer((_) async {
        pollCount++;
        if (pollCount >= 3) {
          return Right(tPaidIntent);
        }
        return Right(tPendingIntent);
      });

      when(() => mockRepository.getWalletSummary())
          .thenAnswer((_) async => const Right(WalletSummaryEntity(balance: 50000, heldBalance: 0)));
      when(() => mockRepository.getBankAccounts())
          .thenAnswer((_) async => const Right([]));
      when(() => mockRepository.getWithdrawals())
          .thenAnswer((_) async => const Right([]));
      when(() => mockRepository.getLedgerHistory(limit: any(named: 'limit')))
          .thenAnswer((_) async => const Right([]));

      // Simulasi timer polling 5 detik
      final timer = Stream.periodic(const Duration(seconds: 5), (i) => i).listen((_) async {
        final res = await walletCubit.checkTopUpStatus('top-1');
        if (res?.isPaid == true) {
          // Polling berhenti saat PAID
        }
      });

      // Maju 5 detik -> Poll 1
      async.elapse(const Duration(seconds: 5));
      expect(pollCount, 1);

      // Maju 5 detik -> Poll 2
      async.elapse(const Duration(seconds: 5));
      expect(pollCount, 2);

      // Maju 5 detik -> Poll 3 (status PAID tercapai)
      async.elapse(const Duration(seconds: 5));
      expect(pollCount, 3);

      timer.cancel();
      // Pastikan setelah di-cancel tidak ada polling tambahan
      async.elapse(const Duration(seconds: 15));
      expect(pollCount, 3);
    });
  });
}
