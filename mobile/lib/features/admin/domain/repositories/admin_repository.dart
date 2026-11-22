import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

abstract class AdminRepository {
  Future<Either<Failure, Map<String, dynamic>>> getMetrics({
    String? startDate,
    String? endDate,
  });

  Future<Either<Failure, Map<String, dynamic>>> getDisputes({
    String? status,
    int? page,
    int? limit,
  });

  Future<Either<Failure, Map<String, dynamic>>> getDisputeDetail(String id);

  Future<Either<Failure, Map<String, dynamic>>> reviewDispute(String id);

  Future<Either<Failure, Map<String, dynamic>>> resolveDispute(
    String id, {
    required String decision,
    required String note,
  });

  Future<Either<Failure, Map<String, dynamic>>> getKycSubmissions({
    String? status,
    String? cursor,
    int? limit,
  });

  Future<Either<Failure, Map<String, dynamic>>> getKycDetail(String id);

  Future<Either<Failure, Map<String, dynamic>>> approveKyc(String id);

  Future<Either<Failure, Map<String, dynamic>>> rejectKyc(
    String id, {
    required String reason,
  });

  Future<Either<Failure, Map<String, dynamic>>> getUsers({
    String? search,
    String? status,
    String? kycStatus,
    String? cursor,
    int? limit,
  });

  Future<Either<Failure, Map<String, dynamic>>> banUser(
    String id, {
    required String reason,
  });

  Future<Either<Failure, Map<String, dynamic>>> unbanUser(String id);

  Future<Either<Failure, Map<String, dynamic>>> getSettings();

  Future<Either<Failure, Map<String, dynamic>>> updateSetting(
    String key,
    dynamic value,
  );

  Future<Either<Failure, Map<String, dynamic>>> getAuditLogs({
    String? cursor,
    int? limit,
  });

  Future<Either<Failure, Map<String, dynamic>>> getWithdrawals({
    String? status,
    String? cursor,
    int? limit,
  });

  Future<Either<Failure, Map<String, dynamic>>> approveWithdrawal(String id);

  Future<Either<Failure, Map<String, dynamic>>> rejectWithdrawal(
    String id, {
    required String reason,
  });
}
