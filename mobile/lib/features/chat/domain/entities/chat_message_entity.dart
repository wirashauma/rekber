import 'package:equatable/equatable.dart';

/// Chat message domain entity matching backend schema
class ChatMessageEntity extends Equatable {
  final String id;
  final String transactionId;
  final String? senderId;
  final String type; // TEXT, IMAGE, SYSTEM
  final String? body;
  final String? fileId;
  final String? fileUrl;
  final bool isRead;
  final DateTime createdAt;

  // Joined
  final String? senderName;
  final String? senderAvatar;

  const ChatMessageEntity({
    required this.id,
    required this.transactionId,
    this.senderId,
    required this.type,
    this.body,
    this.fileId,
    this.fileUrl,
    this.isRead = false,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  bool get isSystem => type.toUpperCase() == 'SYSTEM' || senderId == null;
  bool get isImage => type.toUpperCase() == 'IMAGE';
  bool get isText => type.toUpperCase() == 'TEXT';
  bool isMe(String currentUserId) => senderId != null && senderId == currentUserId;

  factory ChatMessageEntity.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return ChatMessageEntity(
      id: json['id']?.toString() ?? '',
      transactionId: json['transactionId']?.toString() ?? json['transaction_id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? json['sender_id']?.toString(),
      type: (json['type'] ?? 'TEXT').toString().toUpperCase(),
      body: json['body']?.toString() ?? json['message']?.toString(),
      fileId: json['fileId']?.toString() ?? json['file_id']?.toString(),
      fileUrl: json['fileUrl']?.toString() ?? json['attachmentUrl']?.toString() ?? json['file']?['url']?.toString(),
      isRead: json['isRead'] == true || json['is_read'] == true,
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      senderName: json['sender']?['fullName'] ?? json['sender']?['name'] ?? json['senderName'],
      senderAvatar: json['sender']?['avatarUrl'] ?? json['senderAvatar'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transactionId': transactionId,
      'senderId': senderId,
      'type': type,
      'body': body,
      'fileId': fileId,
      'fileUrl': fileUrl,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  ChatMessageEntity copyWith({bool? isRead}) {
    return ChatMessageEntity(
      id: id,
      transactionId: transactionId,
      senderId: senderId,
      type: type,
      body: body,
      fileId: fileId,
      fileUrl: fileUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      senderName: senderName,
      senderAvatar: senderAvatar,
    );
  }

  @override
  List<Object?> get props => [id, transactionId, senderId, type, body, isRead, createdAt];
}
