import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';
import '../../features/chat/domain/entities/chat_message_entity.dart';

class SocketService {
  final ApiService apiService;
  io.Socket? _socket;

  final _messageController = StreamController<ChatMessageEntity>.broadcast();
  final _readController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<ChatMessageEntity> get onMessageReceived => _messageController.stream;
  Stream<Map<String, dynamic>> get onMessageRead => _readController.stream;
  Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  Stream<bool> get onConnectionState => _connectionStateController.stream;

  bool get isConnected => _socket?.connected ?? false;

  SocketService({required this.apiService});

  String _getSocketBaseUrl() {
    final base = ApiService.baseUrl;
    if (base.endsWith('/api')) {
      return base.substring(0, base.length - 4);
    }
    return base;
  }

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) return;

    final token = await apiService.getAccessToken();
    final socketUrl = _getSocketBaseUrl();

    _socket = io.io(
      socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .setAuth({'token': token ?? ''})
          .build(),
    );

    _socket!.onConnect((_) {
      if (kDebugMode) print('Socket.IO connected: ${_socket?.id}');
      _connectionStateController.add(true);
    });

    _socket!.onDisconnect((_) {
      if (kDebugMode) print('Socket.IO disconnected');
      _connectionStateController.add(false);
    });

    _socket!.onConnectError((err) async {
      if (kDebugMode) print('Socket.IO connect error: $err');
      _connectionStateController.add(false);

      // Coba perbarui token jika error autentikasi
      final refreshedToken = await apiService.getAccessToken();
      if (refreshedToken != null && _socket != null) {
        _socket!.io.options?['auth'] = {'token': refreshedToken};
      }
    });

    // Realtime events
    _socket!.on('message:new', (data) {
      if (data != null && data is Map<String, dynamic>) {
        try {
          final message = ChatMessageEntity.fromJson(data);
          _messageController.add(message);
        } catch (e) {
          if (kDebugMode) print('Error parsing socket message: $e');
        }
      }
    });

    _socket!.on('message:read', (data) {
      if (data != null && data is Map<String, dynamic>) {
        _readController.add(data);
      }
    });

    _socket!.on('typing', (data) {
      if (data != null && data is Map<String, dynamic>) {
        _typingController.add(data);
      }
    });

    _socket!.connect();
  }

  void joinRoom(String transactionId) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('join', {'transactionId': transactionId});
    } else {
      connect().then((_) {
        _socket?.emit('join', {'transactionId': transactionId});
      });
    }
  }

  void leaveRoom(String transactionId) {
    _socket?.emit('leave', {'transactionId': transactionId});
  }

  void sendTyping(String transactionId, bool isTyping) {
    _socket?.emit('typing', {'transactionId': transactionId, 'isTyping': isTyping});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _readController.close();
    _typingController.close();
    _connectionStateController.close();
  }
}
