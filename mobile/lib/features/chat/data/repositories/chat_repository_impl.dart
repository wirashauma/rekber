import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/api_service.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ApiService apiService;

  ChatRepositoryImpl({required this.apiService});

  @override
  Future<Either<Failure, List<ChatMessageEntity>>> getMessages(
    String transactionId, {
    String? cursor,
    int? limit,
  }) async {
    try {
      final queryParams = <String>[];
      if (cursor != null) queryParams.add('cursor=$cursor');
      if (limit != null) queryParams.add('limit=$limit');
      final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

      final response = await apiService.get('/transactions/$transactionId/messages$query');
      if (response != null && response['data'] != null) {
        final list = (response['data'] as List)
            .map((e) => ChatMessageEntity.fromJson(e as Map<String, dynamic>))
            .toList();
        return Right(list);
      }
      return const Right([]);
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal memuat pesan: $e'));
    }
  }

  @override
  Future<Either<Failure, ChatMessageEntity>> sendMessage(
    String transactionId, {
    required String type,
    String? body,
    String? fileId,
  }) async {
    try {
      final payload = {
        'type': type.toUpperCase(),
        if (body != null) 'body': body,
        if (fileId != null) 'fileId': fileId,
      };

      final response = await apiService.post('/transactions/$transactionId/messages', payload);
      if (response != null && response['data'] != null) {
        return Right(ChatMessageEntity.fromJson(response['data']));
      }
      return const Left(ServerFailure(message: 'Gagal mengirim pesan.'));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal mengirim pesan: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead(String transactionId) async {
    try {
      await apiService.post('/transactions/$transactionId/messages/read', {});
      return const Right(null);
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal menandai telah dibaca: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> uploadChatImage(String filePath) async {
    try {
      final response = await apiService.postMultipart(
        '/files',
        fieldName: 'file',
        filePath: filePath,
        fields: {'purpose': 'CHAT_IMAGE'},
      );
      if (response != null && response['data'] != null) {
        final id = response['data']['id']?.toString();
        if (id != null) return Right(id);
      }
      return const Left(ServerFailure(message: 'Gagal mengunggah gambar obrolan.'));
    } on ApiException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(ServerFailure(message: 'Gagal mengunggah gambar obrolan: $e'));
    }
  }
}
