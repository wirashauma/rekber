import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/wallet_summary_entity.dart';
import '../entities/ledger_entry_entity.dart';
import '../entities/payment_intent_entity.dart';
import '../entities/bank_account_entity.dart';
import '../entities/withdrawal_entity.dart';

abstract class WalletRepository {
  Future<Either<Failure, WalletSummaryEntity>> getWalletSummary();
  Future<Either<Failure, List<LedgerEntryEntity>>> getLedgerHistory({String? cursor, int? limit});
  Future<Either<Failure, PaymentIntentEntity>> createTopUp({
    required int amount,
    required String method,
    String? bankCode,
  });
  Future<Either<Failure, PaymentIntentEntity>> getTopUpStatus(String id);
  Future<Either<Failure, List<BankAccountEntity>>> getBankAccounts();
  Future<Either<Failure, BankAccountEntity>> createBankAccount({
    required String bankCode,
    required String accountNumber,
    required String accountName,
  });
  Future<Either<Failure, void>> deleteBankAccount(String id);
  Future<Either<Failure, WithdrawalEntity>> requestWithdrawal({
    required String bankAccountId,
    required int amount,
    required String idempotencyKey,
  });
  Future<Either<Failure, List<WithdrawalEntity>>> getWithdrawals();
  Future<Either<Failure, void>> cancelWithdrawal(String id);
}
