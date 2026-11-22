import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../models/transaction_model.dart';
import '../models/public_config_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final ApiService apiService;

  TransactionRepositoryImpl({required this.apiService});

  @override
  Future<Either<Failure, List<TransactionEntity>>> getTransactions() async {
    try {
      final response = await apiService.get('/transactions');
      if (response != null && response['data'] != null) {
        final List<dynamic> list = response['data'];
        final transactions = list.map((e) => TransactionModel.fromJson(e)).toList();
        return Right(transactions);
      }
      return const Right([]);
    } on ApiException catch (e) {
      if (e.statusCode == 409) return Left(ConflictFailure(message: e.message));
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal memuat transaksi: $e'));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> getTransactionById(String id) async {
    try {
      final response = await apiService.get('/transactions/$id');
      if (response != null && response['data'] != null) {
        return Right(TransactionModel.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Data transaksi tidak ditemukan.', statusCode: 404));
    } on ApiException catch (e) {
      if (e.statusCode == 409) return Left(ConflictFailure(message: e.message));
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal memuat detail transaksi: $e'));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> getTransactionByCode(String code) async {
    try {
      final response = await apiService.get('/transactions/code/$code');
      if (response != null && response['data'] != null) {
        return Right(TransactionModel.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Transaksi dengan kode tersebut tidak ditemukan.', statusCode: 404));
    } on ApiException catch (e) {
      if (e.statusCode == 409) return Left(ConflictFailure(message: e.message));
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal mencari transaksi: $e'));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> createTransaction({
    required int amount,
    required String itemDescription,
    required String feePayer,
    String? sellerId,
    String? buyerId,
  }) async {
    try {
      final body = {
        'amount': amount,
        'itemDescription': itemDescription,
        'feePayer': feePayer,
        if (sellerId != null) 'sellerId': sellerId,
        if (buyerId != null) 'buyerId': buyerId,
      };
      final response = await apiService.post('/transactions', body);
      if (response != null && response['data'] != null) {
        return Right(TransactionModel.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Gagal membuat transaksi.'));
    } on ApiException catch (e) {
      if (e.statusCode == 409) return Left(ConflictFailure(message: e.message));
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal membuat transaksi: $e'));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> updateStatus({
    required String id,
    required String status,
  }) async {
    try {
      final response = await apiService.put('/transactions/$id/status', {
        'status': status.toUpperCase(),
      });
      if (response != null && response['data'] != null) {
        return Right(TransactionModel.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Gagal memperbarui status.'));
    } on ApiException catch (e) {
      if (e.statusCode == 409) return Left(ConflictFailure(message: e.message));
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal memperbarui status: $e'));
    }
  }

  @override
  Future<Either<Failure, TransactionEntity>> submitShipment({
    required String id,
    required String courier,
    required String trackingNumber,
    String? note,
    required List<String> fileIds,
  }) async {
    try {
      final body = {
        'courier': courier,
        'trackingNumber': trackingNumber,
        if (note != null && note.isNotEmpty) 'note': note,
        'fileIds': fileIds,
      };
      final response = await apiService.post('/transactions/$id/shipment', body);
      if (response != null && response['data'] != null) {
        return Right(TransactionModel.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Gagal mengirim bukti pengiriman.'));
    } on ApiException catch (e) {
      if (e.statusCode == 409) return Left(ConflictFailure(message: e.message));
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal mengirim bukti pengiriman: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> uploadShipmentProof(String filePath) async {
    try {
      final response = await apiService.postMultipart(
        '/files',
        fieldName: 'file',
        filePath: filePath,
        fields: {'purpose': 'SHIPMENT_PROOF'},
      );
      if (response != null && response['data'] != null) {
        final fileId = response['data']['id']?.toString();
        if (fileId != null) return Right(fileId);
      }
      return const Left(ServerFailure(message: 'Gagal mengunggah berkas.'));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal mengunggah berkas: $e'));
    }
  }

  @override
  Future<Either<Failure, PublicConfigModel>> getPublicConfig() async {
    try {
      final response = await apiService.get('/config/public');
      if (response != null && response['data'] != null) {
        return Right(PublicConfigModel.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Gagal mengambil konfigurasi.'));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal mengambil konfigurasi: $e'));
    }
  }
}
