import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/repositories/kyc_repository.dart';

class KycRepositoryImpl implements KycRepository {
  final ApiService _apiService;

  KycRepositoryImpl({required ApiService apiService}) : _apiService = apiService;

  @override
  Future<Either<Failure, Map<String, dynamic>>> getMyKyc() async {
    try {
      final response = await _apiService.get('/kyc/me');
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadKycFile(File file, String purpose) async {
    try {
      final response = await _apiService.postMultipart(
        '/files',
        fieldName: 'file',
        filePath: file.path,
        fields: {'purpose': purpose},
      );
      final data = response is Map<String, dynamic> ? response['data'] : null;
      final fileId = data?['id'] as String?;
      if (fileId != null) {
        return Right(fileId);
      }
      return const Left(ServerFailure(message: 'Gagal mengunggah berkas KYC.'));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> submitKyc({
    required String fullName,
    required String nik,
    required String idFileId,
    required String selfieFileId,
  }) async {
    try {
      final response = await _apiService.post('/kyc', {
        'fullName': fullName,
        'nik': nik,
        'idFileId': idFileId,
        'selfieFileId': selfieFileId,
      });
      final data = response is Map<String, dynamic> ? response['data'] : null;
      return Right(Map<String, dynamic>.from(data ?? {}));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
