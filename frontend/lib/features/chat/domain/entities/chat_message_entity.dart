import 'package:equatable/equatable.dart';

/// Chat message domain entity
class ChatMessageEntity extends Equatable {
  final String id;
  final String transactionId;
  final String? senderId;
  final String? message;
  final String type; // text, image, system, proof
  final String? attachmentUrl;
  final bool isRead;
  final DateTime createdAt;

  // Joined
  final String? senderName;
  final String? senderAvatar;

  const ChatMessageEntity({
    required this.id,
    required this.transactionId,
    this.senderId,
    this.message,
    required this.type,
    this.attachmentUrl,
    required this.isRead,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  bool get isSystem => type == 'system';
  bool get isProof => type == 'proof';
  bool get isImage => type == 'image';
  bool get isText => type == 'text';
  bool get hasAttachment => attachmentUrl != null;

  @override
  List<Object?> get props => [id, transactionId, type, createdAt];
}
