import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/services/socket_service.dart';

// ── Events ──
abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatStarted extends ChatEvent {
  final String transactionId;

  const ChatStarted({required this.transactionId});

  @override
  List<Object?> get props => [transactionId];
}

class ChatTextMessageSent extends ChatEvent {
  final String? transactionId;
  final String body;

  const ChatTextMessageSent({
    this.transactionId,
    required this.body,
  });

  @override
  List<Object?> get props => [transactionId, body];
}

class ChatImageMessageSent extends ChatEvent {
  final String? transactionId;
  final String? filePath;
  final String? fileId;
  final String? caption;

  const ChatImageMessageSent({
    this.transactionId,
    this.filePath,
    this.fileId,
    this.caption,
  });

  @override
  List<Object?> get props => [transactionId, filePath, fileId, caption];
}

class ChatMessageReceived extends ChatEvent {
  final ChatMessageEntity message;

  const ChatMessageReceived({required this.message});

  @override
  List<Object?> get props => [message];
}

class ChatMessagesReadReceived extends ChatEvent {
  final String userId;

  const ChatMessagesReadReceived({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class ChatTypingSent extends ChatEvent {
  final String? transactionId;
  final bool isTyping;

  const ChatTypingSent({
    this.transactionId,
    required this.isTyping,
  });

  @override
  List<Object?> get props => [transactionId, isTyping];
}

class ChatTypingReceived extends ChatEvent {
  final String userId;
  final String name;
  final bool isTyping;

  const ChatTypingReceived({
    required this.userId,
    required this.name,
    required this.isTyping,
  });

  @override
  List<Object?> get props => [userId, name, isTyping];
}

class ChatLoadMoreRequested extends ChatEvent {
  final String? transactionId;

  const ChatLoadMoreRequested({this.transactionId});

  @override
  List<Object?> get props => [transactionId];
}

class ChatSocketStatusChanged extends ChatEvent {
  final bool isConnected;

  const ChatSocketStatusChanged({required this.isConnected});

  @override
  List<Object?> get props => [isConnected];
}

// ── States ──
class ChatState extends Equatable {
  final bool isLoading;
  final bool isSending;
  final bool isConnected;
  final String transactionId;
  final List<ChatMessageEntity> messages;
  final bool isOpponentTyping;
  final String? opponentTypingName;
  final String? errorMessage;
  final String? nextCursor;

  const ChatState({
    this.isLoading = false,
    this.isSending = false,
    this.isConnected = false,
    this.transactionId = '',
    this.messages = const [],
    this.isOpponentTyping = false,
    this.opponentTypingName,
    this.errorMessage,
    this.nextCursor,
  });

  ChatState copyWith({
    bool? isLoading,
    bool? isSending,
    bool? isConnected,
    String? transactionId,
    List<ChatMessageEntity>? messages,
    bool? isOpponentTyping,
    String? opponentTypingName,
    String? errorMessage,
    String? nextCursor,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isConnected: isConnected ?? this.isConnected,
      transactionId: transactionId ?? this.transactionId,
      messages: messages ?? this.messages,
      isOpponentTyping: isOpponentTyping ?? this.isOpponentTyping,
      opponentTypingName: opponentTypingName ?? this.opponentTypingName,
      errorMessage: errorMessage,
      nextCursor: nextCursor ?? this.nextCursor,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isSending,
        isConnected,
        transactionId,
        messages,
        isOpponentTyping,
        opponentTypingName,
        errorMessage,
      ];
}

// ── BLoC ──
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository repository;
  final SocketService socketService;

  StreamSubscription? _msgSub;
  StreamSubscription? _readSub;
  StreamSubscription? _typingSub;

  List<ChatMessageEntity> get currentMessages => state.messages;

  ChatBloc({
    required this.repository,
    required this.socketService,
  }) : super(const ChatState()) {
    on<ChatStarted>(_onStarted);
    on<ChatTextMessageSent>(_onTextMessageSent);
    on<ChatImageMessageSent>(_onImageMessageSent);
    on<ChatMessageReceived>(_onMessageReceived);
    on<ChatMessagesReadReceived>(_onMessagesReadReceived);
    on<ChatTypingSent>(_onTypingSent);
    on<ChatTypingReceived>(_onTypingReceived);
    on<ChatLoadMoreRequested>(_onLoadMoreRequested);
    on<ChatSocketStatusChanged>(_onSocketStatusChanged);
  }

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    emit(state.copyWith(isLoading: true, transactionId: event.transactionId, messages: []));

    // Hubungkan socket dan join room
    socketService.connect();
    socketService.joinRoom(event.transactionId);

    // Langganan stream socket
    await _msgSub?.cancel();
    _msgSub = socketService.onMessageReceived.listen((msg) {
      if (msg.transactionId == event.transactionId) {
        add(ChatMessageReceived(message: msg));
      }
    });

    await _readSub?.cancel();
    _readSub = socketService.onMessageRead.listen((data) {
      if (data['transactionId'] == event.transactionId) {
        add(ChatMessagesReadReceived(userId: data['userId']?.toString() ?? ''));
      }
    });

    await _typingSub?.cancel();
    _typingSub = socketService.onTyping.listen((data) {
      if (data['transactionId'] == event.transactionId) {
        add(ChatTypingReceived(
          userId: data['userId']?.toString() ?? '',
          name: data['name']?.toString() ?? '',
          isTyping: data['isTyping'] == true,
        ));
      }
    });

    // Ambil riwayat awal via REST
    final result = await repository.getMessages(event.transactionId, limit: 50);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, errorMessage: failure.message)),
      (messages) {
        emit(state.copyWith(isLoading: false, messages: messages, isConnected: true));
        // Tandai dibaca
        repository.markAsRead(event.transactionId);
      },
    );
  }

  void _onSocketStatusChanged(ChatSocketStatusChanged event, Emitter<ChatState> emit) {
    emit(state.copyWith(isConnected: event.isConnected));
  }

  Future<void> _onTextMessageSent(ChatTextMessageSent event, Emitter<ChatState> emit) async {
    final body = event.body.trim();
    if (body.isEmpty) return;
    final txId = event.transactionId ?? state.transactionId;
    if (txId.isEmpty) return;

    emit(state.copyWith(isSending: true));

    final result = await repository.sendMessage(
      txId,
      type: 'TEXT',
      body: body,
    );

    result.fold(
      (failure) => emit(state.copyWith(isSending: false, errorMessage: failure.message)),
      (newMsg) {
        final updatedList = List<ChatMessageEntity>.from(state.messages);
        if (!updatedList.any((m) => m.id == newMsg.id)) {
          // Prepend at index 0 because reversed list starts at bottom
          updatedList.insert(0, newMsg);
        }
        emit(state.copyWith(isSending: false, messages: updatedList));
      },
    );
  }

  Future<void> _onImageMessageSent(ChatImageMessageSent event, Emitter<ChatState> emit) async {
    final txId = event.transactionId ?? state.transactionId;
    if (txId.isEmpty) return;

    emit(state.copyWith(isSending: true));

    String? targetFileId = event.fileId;

    // Jika diberikan file path, upload terlebih dahulu
    if (targetFileId == null && event.filePath != null) {
      final uploadRes = await repository.uploadChatImage(event.filePath!);
      targetFileId = uploadRes.fold<String?>((_) => null, (id) => id);
    }

    if (targetFileId == null) {
      emit(state.copyWith(isSending: false, errorMessage: 'Gagal mengunggah gambar.'));
      return;
    }

    final result = await repository.sendMessage(
      txId,
      type: 'IMAGE',
      fileId: targetFileId,
      body: event.caption,
    );

    result.fold(
      (failure) => emit(state.copyWith(isSending: false, errorMessage: failure.message)),
      (newMsg) {
        final updatedList = List<ChatMessageEntity>.from(state.messages);
        if (!updatedList.any((m) => m.id == newMsg.id)) {
          updatedList.insert(0, newMsg);
        }
        emit(state.copyWith(isSending: false, messages: updatedList));
      },
    );
  }

  void _onMessageReceived(ChatMessageReceived event, Emitter<ChatState> emit) {
    final updatedList = List<ChatMessageEntity>.from(state.messages);
    if (!updatedList.any((m) => m.id == event.message.id)) {
      updatedList.insert(0, event.message);
    }
    emit(state.copyWith(messages: updatedList));
    // Tandai dibaca
    repository.markAsRead(state.transactionId);
  }

  void _onMessagesReadReceived(ChatMessagesReadReceived event, Emitter<ChatState> emit) {
    final updatedList = state.messages.map((m) {
      return m.copyWith(isRead: true);
    }).toList();
    emit(state.copyWith(messages: updatedList));
  }

  void _onTypingSent(ChatTypingSent event, Emitter<ChatState> emit) {
    final txId = event.transactionId ?? state.transactionId;
    if (txId.isNotEmpty) {
      socketService.sendTyping(txId, event.isTyping);
    }
  }

  void _onTypingReceived(ChatTypingReceived event, Emitter<ChatState> emit) {
    emit(state.copyWith(
      isOpponentTyping: event.isTyping,
      opponentTypingName: event.isTyping ? event.name : null,
    ));
  }

  Future<void> _onLoadMoreRequested(ChatLoadMoreRequested event, Emitter<ChatState> emit) async {
    if (state.messages.isEmpty) return;
    final txId = event.transactionId ?? state.transactionId;
    if (txId.isEmpty) return;

    // In a reversed list where newest is index 0, the oldest message is at the end
    final oldestId = state.messages.last.id;

    final result = await repository.getMessages(txId, cursor: oldestId, limit: 30);
    result.fold(
      (_) {},
      (olderMessages) {
        if (olderMessages.isNotEmpty) {
          final merged = [...state.messages, ...olderMessages];
          emit(state.copyWith(messages: merged));
        }
      },
    );
  }

  @override
  Future<void> close() {
    if (state.transactionId.isNotEmpty) {
      socketService.leaveRoom(state.transactionId);
    }
    _msgSub?.cancel();
    _readSub?.cancel();
    _typingSub?.cancel();
    return super.close();
  }
}
