import 'dart:convert';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/wallet_summary_entity.dart';
import '../../domain/entities/payment_intent_entity.dart';
import '../../domain/entities/bank_account_entity.dart';
import '../../domain/entities/withdrawal_entity.dart';
import '../../domain/entities/ledger_entry_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import 'wallet_state.dart';

class WalletCubit extends Cubit<WalletState> {
  final WalletRepository repository;

  WalletSummaryEntity? currentSummary;

  WalletCubit({required this.repository}) : super(WalletInitial());

  String _generateSecureKey() {
    final random = Random.secure();
    final values = List<int>.generate(24, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  Future<void> loadWalletData() async {
    emit(WalletLoading());
    try {
      final summaryRes = await repository.getWalletSummary();
      final bankAccountsRes = await repository.getBankAccounts();
      final withdrawalsRes = await repository.getWithdrawals();
      final ledgerRes = await repository.getLedgerHistory(limit: 50);

      final summary = summaryRes.fold(
        (_) => const WalletSummaryEntity(balance: 0, heldBalance: 0),
        (s) => s,
      );
      currentSummary = summary;

      final bankAccounts = bankAccountsRes.fold((_) => <BankAccountEntity>[], (b) => b);
      final withdrawals = withdrawalsRes.fold((_) => <WithdrawalEntity>[], (w) => w);
      final ledgerEntries = ledgerRes.fold((_) => <LedgerEntryEntity>[], (l) => l);

      emit(WalletLoaded(
        summary: summary,
        bankAccounts: bankAccounts,
        withdrawals: withdrawals,
        ledgerEntries: ledgerEntries,
      ));
    } catch (e) {
      emit(WalletError(message: 'Gagal memuat data dompet: $e'));
    }
  }

  Future<PaymentIntentEntity?> createTopUp({
    required int amount,
    required String method,
    String? bankCode,
  }) async {
    emit(const WalletActionLoading(message: 'Membuat permintaan top-up...'));
    final result = await repository.createTopUp(
      amount: amount,
      method: method,
      bankCode: bankCode,
    );

    return result.fold(
      (failure) {
        emit(WalletActionFailure(message: failure.message));
        return null;
      },
      (intent) {
        emit(TopUpCreatedSuccess(paymentIntent: intent));
        return intent;
      },
    );
  }

  Future<PaymentIntentEntity?> checkTopUpStatus(String topUpId) async {
    final result = await repository.getTopUpStatus(topUpId);
    return result.fold(
      (_) => null,
      (intent) {
        if (intent.isPaid) {
          loadWalletData();
        }
        return intent;
      },
    );
  }

  Future<bool> addBankAccount({
    required String bankCode,
    required String accountNumber,
    required String accountName,
  }) async {
    emit(const WalletActionLoading(message: 'Menyimpan rekening bank...'));
    final result = await repository.createBankAccount(
      bankCode: bankCode,
      accountNumber: accountNumber,
      accountName: accountName,
    );

    return result.fold(
      (failure) {
        emit(WalletActionFailure(message: failure.message));
        return false;
      },
      (bank) {
        emit(const WalletActionSuccess(message: 'Rekening bank berhasil disimpan.'));
        loadWalletData();
        return true;
      },
    );
  }

  Future<void> deleteBankAccount(String id) async {
    emit(const WalletActionLoading(message: 'Menghapus rekening...'));
    final result = await repository.deleteBankAccount(id);
    result.fold(
      (failure) => emit(WalletActionFailure(message: failure.message)),
      (_) {
        emit(const WalletActionSuccess(message: 'Rekening bank berhasil dihapus.'));
        loadWalletData();
      },
    );
  }

  Future<bool> submitWithdrawal({
    required String bankAccountId,
    required int amount,
  }) async {
    emit(const WalletActionLoading(message: 'Mengajukan penarikan dana...'));
    final idempotencyKey = _generateSecureKey();

    final result = await repository.requestWithdrawal(
      bankAccountId: bankAccountId,
      amount: amount,
      idempotencyKey: idempotencyKey,
    );

    return result.fold(
      (failure) {
        final isKyc = failure.message.toUpperCase().contains('KYC');
        emit(WalletActionFailure(
          message: failure.message,
          isKycRequired: isKyc,
        ));
        return false;
      },
      (withdrawal) {
        emit(const WalletActionSuccess(message: 'Permintaan penarikan berhasil diajukan!'));
        loadWalletData();
        return true;
      },
    );
  }

  Future<void> cancelWithdrawal(String id) async {
    emit(const WalletActionLoading(message: 'Membatalkan penarikan...'));
    final result = await repository.cancelWithdrawal(id);
    result.fold(
      (failure) => emit(WalletActionFailure(message: failure.message)),
      (_) {
        emit(const WalletActionSuccess(message: 'Penarikan berhasil dibatalkan.'));
        loadWalletData();
      },
    );
  }
}
