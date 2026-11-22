import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/entities/wallet_summary_entity.dart';
import '../../domain/entities/ledger_entry_entity.dart';
import '../../domain/entities/payment_intent_entity.dart';
import '../../domain/entities/bank_account_entity.dart';
import '../../domain/entities/withdrawal_entity.dart';
import '../../domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  final ApiService apiService;

  WalletRepositoryImpl({required this.apiService});

  @override
  Future<Either<Failure, WalletSummaryEntity>> getWalletSummary() async {
    try {
      final response = await apiService.get('/wallet');
      if (response != null && response['data'] != null) {
        return Right(WalletSummaryModel.fromJson(response['data']));
      }
      return const Right(WalletSummaryEntity(balance: 0, heldBalance: 0));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal memuat saldo: $e'));
    }
  }

  @override
  Future<Either<Failure, List<LedgerEntryEntity>>> getLedgerHistory({
    String? cursor,
    int? limit,
  }) async {
    try {
      final queryParams = <String>[];
      if (cursor != null) queryParams.add('cursor=$cursor');
      if (limit != null) queryParams.add('limit=$limit');
      final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

      final response = await apiService.get('/wallet/ledger$query');
      if (response != null && response['data'] != null) {
        final dynamic rawEntries = response['data'] is List
            ? response['data']
            : (response['data']['entries'] ?? []);
        final list = (rawEntries as List).map((e) => LedgerEntryModel.fromJson(e)).toList();
        return Right(list);
      }
      return const Right([]);
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal memuat mutasi: $e'));
    }
  }

  @override
  Future<Either<Failure, PaymentIntentEntity>> createTopUp({
    required int amount,
    required String method,
    String? bankCode,
  }) async {
    try {
      final body = {
        'amount': amount,
        'method': method.toUpperCase(),
        if (bankCode != null && bankCode.isNotEmpty) 'bankCode': bankCode.toUpperCase(),
      };
      final response = await apiService.post('/wallet/topups', body);
      if (response != null && response['data'] != null) {
        return Right(PaymentIntentModel.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Gagal membuat permintaan top up.'));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal membuat top up: $e'));
    }
  }

  @override
  Future<Either<Failure, PaymentIntentEntity>> getTopUpStatus(String id) async {
    try {
      final response = await apiService.get('/wallet/topups/$id');
      if (response != null && response['data'] != null) {
        return Right(PaymentIntentModel.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Status top up tidak ditemukan.', statusCode: 404));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal memuat status top up: $e'));
    }
  }

  @override
  Future<Either<Failure, List<BankAccountEntity>>> getBankAccounts() async {
    try {
      final response = await apiService.get('/bank-accounts');
      if (response != null && response['data'] != null) {
        final list = (response['data'] as List).map((e) => BankAccountModel.fromJson(e)).toList();
        return Right(list);
      }
      return const Right([]);
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal memuat rekening bank: $e'));
    }
  }

  @override
  Future<Either<Failure, BankAccountEntity>> createBankAccount({
    required String bankCode,
    required String accountNumber,
    required String accountName,
  }) async {
    try {
      final body = {
        'bankCode': bankCode.toUpperCase(),
        'accountNumber': accountNumber,
        'accountName': accountName,
      };
      final response = await apiService.post('/bank-accounts', body);
      if (response != null && response['data'] != null) {
        return Right(BankAccountModel.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Gagal menambahkan rekening bank.'));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal menambahkan rekening bank: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteBankAccount(String id) async {
    try {
      await apiService.delete('/bank-accounts/$id');
      return const Right(null);
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal menghapus rekening bank: $e'));
    }
  }

  @override
  Future<Either<Failure, WithdrawalEntity>> requestWithdrawal({
    required String bankAccountId,
    required int amount,
    required String idempotencyKey,
  }) async {
    try {
      final body = {
        'bankAccountId': bankAccountId,
        'amount': amount,
      };
      final headers = {
        'Idempotency-Key': idempotencyKey,
      };
      final response = await apiService.post('/wallet/withdrawals', body, headers: headers);
      if (response != null && response['data'] != null) {
        return Right(WithdrawalModel.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Gagal mengajukan penarikan dana.'));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal mengajukan penarikan: $e'));
    }
  }

  @override
  Future<Either<Failure, List<WithdrawalEntity>>> getWithdrawals() async {
    try {
      final response = await apiService.get('/wallet/withdrawals');
      if (response != null && response['data'] != null) {
        final list = (response['data'] as List).map((e) => WithdrawalModel.fromJson(e)).toList();
        return Right(list);
      }
      return const Right([]);
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal memuat riwayat penarikan: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> cancelWithdrawal(String id) async {
    try {
      await apiService.post('/wallet/withdrawals/$id/cancel', {});
      return const Right(null);
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal membatalkan penarikan: $e'));
    }
  }
}
