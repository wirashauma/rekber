import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/chat_message_entity.dart';

abstract class ChatRepository {
  Future<Either<Failure, List<ChatMessageEntity>>> getMessages(
    String transactionId, {
    String? cursor,
    int? limit,
  });

  Future<Either<Failure, ChatMessageEntity>> sendMessage(
    String transactionId, {
    required String type,
    String? body,
    String? fileId,
  });

  Future<Either<Failure, void>> markAsRead(String transactionId);

  Future<Either<Failure, String>> uploadChatImage(String filePath);
}
