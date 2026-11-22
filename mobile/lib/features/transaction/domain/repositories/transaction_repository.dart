import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/transaction_entity.dart';
import '../../data/models/public_config_model.dart';

abstract class TransactionRepository {
  Future<Either<Failure, List<TransactionEntity>>> getTransactions();
  Future<Either<Failure, TransactionEntity>> getTransactionById(String id);
  Future<Either<Failure, TransactionEntity>> getTransactionByCode(String code);
  Future<Either<Failure, TransactionEntity>> createTransaction({
    required int amount,
    required String itemDescription,
    required String feePayer,
    String? sellerId,
    String? buyerId,
  });
  Future<Either<Failure, TransactionEntity>> updateStatus({
    required String id,
    required String status,
  });
  Future<Either<Failure, TransactionEntity>> submitShipment({
    required String id,
    required String courier,
    required String trackingNumber,
    String? note,
    required List<String> fileIds,
  });
  Future<Either<Failure, String>> uploadShipmentProof(String filePath);
  Future<Either<Failure, PublicConfigModel>> getPublicConfig();
}
