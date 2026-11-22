import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/entities/dispute_entity.dart';
import '../../domain/repositories/dispute_repository.dart';

class DisputeRepositoryImpl implements DisputeRepository {
  final ApiService apiService;

  DisputeRepositoryImpl({required this.apiService});

  @override
  Future<Either<Failure, DisputeEntity>> openDispute({
    required String transactionId,
    required String reason,
    required String description,
    List<String>? fileIds,
  }) async {
    try {
      final body = {
        'reason': reason.toUpperCase(),
        'description': description,
        if (fileIds != null && fileIds.isNotEmpty) 'fileIds': fileIds,
      };

      final response = await apiService.post('/transactions/$transactionId/dispute', body);
      if (response != null && response['data'] != null) {
        return Right(DisputeEntity.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Gagal mengajukan sengketa.'));
    } on ApiException catch (e) {
      if (e.statusCode == 409) return Left(ConflictFailure(message: e.message));
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Terjadi kesalahan sistem: $e'));
    }
  }

  @override
  Future<Either<Failure, DisputeEntity>> getDisputeById(String id) async {
    try {
      final response = await apiService.get('/disputes/$id');
      if (response != null && response['data'] != null) {
        return Right(DisputeEntity.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Sengketa tidak ditemukan.', statusCode: 404));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal memuat sengketa: $e'));
    }
  }

  @override
  Future<Either<Failure, DisputeEntity>> getDisputeByTransactionId(String transactionId) async {
    try {
      final response = await apiService.get('/transactions/$transactionId/dispute');
      if (response != null && response['data'] != null) {
        return Right(DisputeEntity.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Sengketa untuk transaksi ini tidak ditemukan.', statusCode: 404));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal memuat sengketa: $e'));
    }
  }

  @override
  Future<Either<Failure, DisputeEvidenceEntity>> submitEvidence({
    required String disputeId,
    String? note,
    List<String>? fileIds,
  }) async {
    try {
      final body = {
        if (note != null && note.isNotEmpty) 'note': note,
        if (fileIds != null && fileIds.isNotEmpty) 'fileIds': fileIds,
      };

      final response = await apiService.post('/disputes/$disputeId/evidence', body);
      if (response != null && response['data'] != null) {
        return Right(DisputeEvidenceEntity.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Gagal menambahkan bukti sengketa.'));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal menambahkan bukti: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> uploadDisputeEvidence(String filePath) async {
    try {
      final response = await apiService.postMultipart(
        '/files',
        fieldName: 'file',
        filePath: filePath,
        fields: {'purpose': 'DISPUTE_EVIDENCE'},
      );
      if (response != null && response['data'] != null) {
        final id = response['data']['id']?.toString();
        if (id != null) return Right(id);
      }
      return const Left(ServerFailure(message: 'Gagal mengunggah berkas bukti.'));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal mengunggah berkas: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> getFileUrl(String fileId) async {
    try {
      final response = await apiService.get('/files/$fileId/url');
      if (response != null && response['data'] != null) {
        final url = response['data']['url']?.toString();
        if (url != null) return Right(url);
      }
      return const Left(ServerFailure(message: 'URL berkas tidak ditemukan.'));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal mengambil URL berkas: $e'));
    }
  }
}
