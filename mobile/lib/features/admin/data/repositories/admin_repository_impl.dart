import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/repositories/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  final ApiService _apiService;

  AdminRepositoryImpl({required ApiService apiService})
      : _apiService = apiService;

  Failure _mapError(dynamic e) {
    if (e is ApiException) {
      if (e.statusCode == 403) {
        return const ServerFailure(
          message: 'Akses ditolak: Hanya akun Administrator yang diizinkan.',
        );
      }
      return ServerFailure(message: e.message);
    }
    return ServerFailure(message: e.toString());
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getMetrics({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      final uri = Uri(path: '/admin/metrics', queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await _apiService.get(uri.toString());
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDisputes({
    String? status,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty && status != 'Semua') {
        queryParams['status'] = status;
      }
      if (page != null) queryParams['page'] = page.toString();
      if (limit != null) queryParams['limit'] = limit.toString();
      final uri = Uri(path: '/admin/disputes', queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await _apiService.get(uri.toString());
      return Right(Map<String, dynamic>.from(response is Map<String, dynamic> ? response : {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDisputeDetail(String id) async {
    try {
      final response = await _apiService.get('/admin/disputes/$id');
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> reviewDispute(String id) async {
    try {
      final response = await _apiService.post('/admin/disputes/$id/review', {});
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> resolveDispute(
    String id, {
    required String decision,
    required String note,
  }) async {
    try {
      final response = await _apiService.post('/admin/disputes/$id/resolve', {
        'decision': decision,
        'note': note,
      });
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getKycSubmissions({
    String? status,
    String? cursor,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty && status != 'Semua') {
        queryParams['status'] = status;
      }
      if (cursor != null) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit.toString();
      final uri = Uri(path: '/admin/kyc', queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await _apiService.get(uri.toString());
      return Right(Map<String, dynamic>.from(response is Map<String, dynamic> ? response : {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getKycDetail(String id) async {
    try {
      final response = await _apiService.get('/admin/kyc/$id');
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> approveKyc(String id) async {
    try {
      final response = await _apiService.post('/admin/kyc/$id/approve', {});
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> rejectKyc(
    String id, {
    required String reason,
  }) async {
    try {
      final response = await _apiService.post('/admin/kyc/$id/reject', {
        'reason': reason,
      });
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUsers({
    String? search,
    String? status,
    String? kycStatus,
    String? cursor,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (kycStatus != null && kycStatus.isNotEmpty) {
        queryParams['kycStatus'] = kycStatus;
      }
      if (cursor != null) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit.toString();
      final uri = Uri(path: '/admin/users', queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await _apiService.get(uri.toString());
      return Right(Map<String, dynamic>.from(response is Map<String, dynamic> ? response : {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> banUser(
    String id, {
    required String reason,
  }) async {
    try {
      final response = await _apiService.post('/admin/users/$id/ban', {
        'reason': reason,
      });
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> unbanUser(String id) async {
    try {
      final response = await _apiService.post('/admin/users/$id/unban', {});
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getSettings() async {
    try {
      final response = await _apiService.get('/admin/settings');
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateSetting(
    String key,
    dynamic value,
  ) async {
    try {
      final response = await _apiService.put('/admin/settings', {
        'key': key,
        'value': value,
      });
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getAuditLogs({
    String? cursor,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (cursor != null) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit.toString();
      final uri = Uri(path: '/admin/audit-logs', queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await _apiService.get(uri.toString());
      return Right(Map<String, dynamic>.from(response is Map<String, dynamic> ? response : {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getWithdrawals({
    String? status,
    String? cursor,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty && status != 'Semua') {
        queryParams['status'] = status;
      }
      if (cursor != null) queryParams['cursor'] = cursor;
      if (limit != null) queryParams['limit'] = limit.toString();
      final uri = Uri(path: '/admin/withdrawals', queryParameters: queryParams.isEmpty ? null : queryParams);
      final response = await _apiService.get(uri.toString());
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> approveWithdrawal(String id) async {
    try {
      final response = await _apiService.post('/admin/withdrawals/$id/approve', {});
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> rejectWithdrawal(
    String id, {
    required String reason,
  }) async {
    try {
      final response = await _apiService.post('/admin/withdrawals/$id/reject', {
        'reason': reason,
      });
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } catch (e) {
      return Left(_mapError(e));
    }
  }
}
