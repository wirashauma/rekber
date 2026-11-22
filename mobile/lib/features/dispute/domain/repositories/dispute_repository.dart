import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/dispute_entity.dart';

abstract class DisputeRepository {
  Future<Either<Failure, DisputeEntity>> openDispute({
    required String transactionId,
    required String reason,
    required String description,
    List<String>? fileIds,
  });

  Future<Either<Failure, DisputeEntity>> getDisputeById(String id);

  Future<Either<Failure, DisputeEntity>> getDisputeByTransactionId(String transactionId);

  Future<Either<Failure, DisputeEvidenceEntity>> submitEvidence({
    required String disputeId,
    String? note,
    List<String>? fileIds,
  });

  Future<Either<Failure, String>> uploadDisputeEvidence(String filePath);
  Future<Either<Failure, String>> getFileUrl(String fileId);
}
