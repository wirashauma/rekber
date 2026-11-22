import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:rekber/features/auth/domain/entities/user_entity.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_state.dart';
import 'package:rekber/features/transaction/domain/entities/transaction_entity.dart';
import 'package:rekber/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:rekber/features/transaction/presentation/cubit/transaction_cubit.dart';
import 'package:rekber/features/transaction/presentation/pages/transaction_detail_page.dart';
import 'package:rekber/features/wallet/domain/entities/wallet_summary_entity.dart';
import 'package:rekber/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:rekber/features/wallet/presentation/cubit/wallet_cubit.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockWalletRepository extends Mock implements WalletRepository {}
class MockAuthBloc extends Mock implements AuthBloc {}

void main() {
  late MockTransactionRepository mockTxRepo;
  late MockWalletRepository mockWalletRepo;
  late MockAuthBloc mockAuthBloc;
  late TransactionCubit txCubit;
  late WalletCubit walletCubit;

  final buyerUser = UserEntity(
    id: 'user-buyer-id',
    fullName: 'Pembeli Hebat',
    email: 'buyer@test.com',
    role: 'USER',
    kycStatus: 'verified',
    isActive: true,
    createdAt: DateTime.now(),
  );

  final sellerUser = UserEntity(
    id: 'user-seller-id',
    fullName: 'Penjual Terpercaya',
    email: 'seller@test.com',
    role: 'USER',
    kycStatus: 'verified',
    isActive: true,
    createdAt: DateTime.now(),
  );

  setUp(() {
    mockTxRepo = MockTransactionRepository();
    mockWalletRepo = MockWalletRepository();
    mockAuthBloc = MockAuthBloc();
    txCubit = TransactionCubit(repository: mockTxRepo);
    walletCubit = WalletCubit(repository: mockWalletRepo);

    when(() => mockWalletRepo.getWalletSummary())
        .thenAnswer((_) async => const Right(WalletSummaryEntity(balance: 1000000, heldBalance: 0)));
    when(() => mockWalletRepo.getBankAccounts())
        .thenAnswer((_) async => const Right([]));
    when(() => mockWalletRepo.getWithdrawals())
        .thenAnswer((_) async => const Right([]));
    when(() => mockWalletRepo.getLedgerHistory(limit: any(named: 'limit')))
        .thenAnswer((_) async => const Right([]));
  });

  tearDown(() {
    txCubit.close();
    walletCubit.close();
  });

  Widget buildTestWidget(TransactionEntity tx, UserEntity currentUser) {
    when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(user: currentUser, activeRole: 'buyer'));
    when(() => mockAuthBloc.stream).thenAnswer((_) => Stream.value(AuthAuthenticated(user: currentUser, activeRole: 'buyer')));

    when(() => mockTxRepo.getTransactionById(tx.id)).thenAnswer((_) async => Right(tx));

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: mockAuthBloc),
        BlocProvider<TransactionCubit>.value(value: txCubit),
        BlocProvider<WalletCubit>.value(value: walletCubit),
      ],
      child: MaterialApp(
        home: TransactionDetailPage(
          transactionId: tx.id,
          initialTransaction: tx,
        ),
      ),
    );
  }

  testWidgets('Pembeli x PENDING: tombol Bayar dari Saldo dan Batalkan Transaksi tampil', (tester) async {
    final tx = TransactionEntity(
      id: 'tx-pending-1',
      txCode: 'TRX-PEND01',
      buyerId: 'user-buyer-id',
      sellerId: 'user-seller-id',
      amount: 100000,
      platformFee: 2000,
      status: 'PENDING',
      description: 'Barang Tes Pending',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(tx, buyerUser));
    await tester.pumpAndSettle();

    expect(find.text('BAYAR DARI SALDO'), findsOneWidget);
    expect(find.text('BATALKAN TRANSAKSI'), findsOneWidget);
  });

  testWidgets('Pembeli x SHIPPED: tombol Konfirmasi Diterima & banner auto-release tampil', (tester) async {
    final tx = TransactionEntity(
      id: 'tx-shipped-1',
      txCode: 'TRX-SHIP01',
      buyerId: 'user-buyer-id',
      sellerId: 'user-seller-id',
      amount: 150000,
      platformFee: 3000,
      status: 'SHIPPED',
      description: 'Barang Dikirim',
      autoReleaseAt: DateTime.now().add(const Duration(hours: 48)),
      courier: 'JNE',
      trackingNumber: 'JNE123456789',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(tx, buyerUser));
    await tester.pumpAndSettle();

    expect(find.text('KONFIRMASI DITERIMA'), findsOneWidget);
    expect(find.text('Auto-Release Otomatis'), findsOneWidget);
  });

  testWidgets('Penjual x PAID: tombol Tandai Dikirim tampil', (tester) async {
    final tx = TransactionEntity(
      id: 'tx-paid-1',
      txCode: 'TRX-PAID01',
      buyerId: 'user-buyer-id',
      sellerId: 'user-seller-id',
      amount: 200000,
      platformFee: 4000,
      status: 'PAID',
      description: 'Pesanan Telah Dibayar',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(tx, sellerUser));
    await tester.pumpAndSettle();

    expect(find.text('TANDAI DIKIRIM'), findsOneWidget);
  });

  testWidgets('Penjual x PENDING: tombol Batalkan Transaksi tampil', (tester) async {
    final tx = TransactionEntity(
      id: 'tx-pending-2',
      txCode: 'TRX-PEND02',
      buyerId: 'user-buyer-id',
      sellerId: 'user-seller-id',
      amount: 50000,
      platformFee: 1000,
      status: 'PENDING',
      description: 'Pesanan Baru',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(buildTestWidget(tx, sellerUser));
    await tester.pumpAndSettle();

    expect(find.text('BATALKAN TRANSAKSI'), findsOneWidget);
  });
}
