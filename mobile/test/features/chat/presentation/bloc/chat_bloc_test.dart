import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:rekber/core/services/socket_service.dart';
import 'package:rekber/features/chat/domain/entities/chat_message_entity.dart';
import 'package:rekber/features/chat/domain/repositories/chat_repository.dart';
import 'package:rekber/features/chat/presentation/bloc/chat_bloc.dart';

class MockChatRepository extends Mock implements ChatRepository {}
class MockSocketService extends Mock implements SocketService {}

void main() {
  late MockChatRepository mockRepository;
  late MockSocketService mockSocketService;
  late StreamController<ChatMessageEntity> msgReceivedController;
  late StreamController<Map<String, dynamic>> msgReadController;
  late StreamController<Map<String, dynamic>> typingController;

  final tMessage1 = ChatMessageEntity(
    id: 'msg_1',
    transactionId: 'tx_100',
    senderId: 'user_a',
    type: 'TEXT',
    body: 'Halo gan barang masih ready?',
    createdAt: DateTime.parse('2026-03-25T10:00:00Z'),
    isRead: false,
  );

  final tMessage2 = ChatMessageEntity(
    id: 'msg_2',
    transactionId: 'tx_100',
    senderId: 'user_b',
    type: 'TEXT',
    body: 'Ready gan langsung checkout saja.',
    createdAt: DateTime.parse('2026-03-25T10:01:00Z'),
    isRead: false,
  );

  final tImageMessage = ChatMessageEntity(
    id: 'msg_3',
    transactionId: 'tx_100',
    senderId: 'user_b',
    type: 'IMAGE',
    fileId: 'file_img_99',
    createdAt: DateTime.parse('2026-03-25T10:02:00Z'),
    isRead: false,
  );

  setUp(() {
    mockRepository = MockChatRepository();
    mockSocketService = MockSocketService();

    msgReceivedController = StreamController<ChatMessageEntity>.broadcast();
    msgReadController = StreamController<Map<String, dynamic>>.broadcast();
    typingController = StreamController<Map<String, dynamic>>.broadcast();

    when(() => mockSocketService.onMessageReceived)
        .thenAnswer((_) => msgReceivedController.stream);
    when(() => mockSocketService.onMessageRead)
        .thenAnswer((_) => msgReadController.stream);
    when(() => mockSocketService.onTyping)
        .thenAnswer((_) => typingController.stream);
    when(() => mockSocketService.isConnected).thenReturn(true);
    when(() => mockSocketService.connect()).thenAnswer((_) async {});
    when(() => mockSocketService.joinRoom(any())).thenReturn(null);
    when(() => mockSocketService.leaveRoom(any())).thenReturn(null);
    when(() => mockSocketService.sendTyping(any(), any())).thenReturn(null);
  });

  tearDown(() {
    msgReceivedController.close();
    msgReadController.close();
    typingController.close();
  });

  group('ChatBloc - ChatStarted & Reconnect', () {
    blocTest<ChatBloc, ChatState>(
      'menghubungkan socket, join room, dan memuat pesan awal riwayat dari repository',
      build: () {
        when(() => mockRepository.getMessages('tx_100', limit: any(named: 'limit')))
            .thenAnswer((_) async => Right([tMessage1]));
        when(() => mockRepository.markAsRead('tx_100'))
            .thenAnswer((_) async => const Right(true));

        return ChatBloc(
          repository: mockRepository,
          socketService: mockSocketService,
        );
      },
      act: (bloc) => bloc.add(const ChatStarted(transactionId: 'tx_100')),
      expect: () => [
        const ChatState(isLoading: true, transactionId: 'tx_100', messages: []),
        ChatState(
          isLoading: false,
          isConnected: true,
          transactionId: 'tx_100',
          messages: [tMessage1],
        ),
      ],
      verify: (_) {
        verify(() => mockSocketService.connect()).called(1);
        verify(() => mockSocketService.joinRoom('tx_100')).called(1);
        verify(() => mockRepository.getMessages('tx_100', limit: 50)).called(1);
        verify(() => mockRepository.markAsRead('tx_100')).called(1);
      },
    );
  });

  group('ChatBloc - Kirim Pesan Teks & Gambar', () {
    blocTest<ChatBloc, ChatState>(
      'mengirim pesan teks sukses menambah pesan ke state',
      build: () {
        when(() => mockRepository.sendMessage(
              'tx_100',
              type: 'TEXT',
              body: 'Test kirim pesan',
            )).thenAnswer((_) async => Right(tMessage2));

        return ChatBloc(
          repository: mockRepository,
          socketService: mockSocketService,
        );
      },
      seed: () => const ChatState(transactionId: 'tx_100', messages: []),
      act: (bloc) => bloc.add(const ChatTextMessageSent(
        transactionId: 'tx_100',
        body: 'Test kirim pesan',
      )),
      expect: () => [
        const ChatState(isSending: true, transactionId: 'tx_100', messages: []),
        ChatState(isSending: false, transactionId: 'tx_100', messages: [tMessage2]),
      ],
      verify: (_) {
        verify(() => mockRepository.sendMessage(
              'tx_100',
              type: 'TEXT',
              body: 'Test kirim pesan',
            )).called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'mengirim pesan gambar dengan fileId sukses memanggil sendMessage type IMAGE',
      build: () {
        when(() => mockRepository.sendMessage(
              'tx_100',
              type: 'IMAGE',
              fileId: 'file_img_99',
              body: any(named: 'body'),
            )).thenAnswer((_) async => Right(tImageMessage));

        return ChatBloc(
          repository: mockRepository,
          socketService: mockSocketService,
        );
      },
      seed: () => const ChatState(transactionId: 'tx_100', messages: []),
      act: (bloc) => bloc.add(const ChatImageMessageSent(
        transactionId: 'tx_100',
        fileId: 'file_img_99',
      )),
      expect: () => [
        const ChatState(isSending: true, transactionId: 'tx_100', messages: []),
        ChatState(isSending: false, transactionId: 'tx_100', messages: [tImageMessage]),
      ],
    );
  });

  group('ChatBloc - Terima Pesan & Dibaca', () {
    blocTest<ChatBloc, ChatState>(
      'menerima pesan realtime menambahkan pesan ke state dan memanggil markAsRead',
      build: () {
        when(() => mockRepository.markAsRead('tx_100'))
            .thenAnswer((_) async => const Right(true));

        return ChatBloc(
          repository: mockRepository,
          socketService: mockSocketService,
        );
      },
      seed: () => ChatState(transactionId: 'tx_100', messages: [tMessage1]),
      act: (bloc) => bloc.add(ChatMessageReceived(message: tMessage2)),
      expect: () => [
        ChatState(transactionId: 'tx_100', messages: [tMessage2, tMessage1]),
      ],
      verify: (_) {
        verify(() => mockRepository.markAsRead('tx_100')).called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'menerima event pesan dibaca mengupdate status isRead pada list pesan',
      build: () => ChatBloc(
        repository: mockRepository,
        socketService: mockSocketService,
      ),
      seed: () => ChatState(
        transactionId: 'tx_100',
        messages: [tMessage1.copyWith(isRead: false)],
      ),
      act: (bloc) => bloc.add(const ChatMessagesReadReceived(userId: 'user_b')),
      expect: () => [
        ChatState(
          transactionId: 'tx_100',
          messages: [tMessage1.copyWith(isRead: true)],
        ),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'ChatTypingSent memicu socketService.sendTyping',
      build: () => ChatBloc(
        repository: mockRepository,
        socketService: mockSocketService,
      ),
      seed: () => const ChatState(transactionId: 'tx_100'),
      act: (bloc) => bloc.add(const ChatTypingSent(isTyping: true)),
      verify: (_) {
        verify(() => mockSocketService.sendTyping('tx_100', true)).called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'ChatTypingReceived memperbarui isOpponentTyping dan nama pengetik',
      build: () => ChatBloc(
        repository: mockRepository,
        socketService: mockSocketService,
      ),
      act: (bloc) => bloc.add(const ChatTypingReceived(
        userId: 'user_b',
        name: 'Siti',
        isTyping: true,
      )),
      expect: () => [
        const ChatState(isOpponentTyping: true, opponentTypingName: 'Siti'),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'ChatLoadMoreRequested mengambil pesan lama dan menggabungkan ke state',
      build: () {
        when(() => mockRepository.getMessages('tx_100', cursor: 'msg_2', limit: 30))
            .thenAnswer((_) async => Right([tMessage1]));
        return ChatBloc(
          repository: mockRepository,
          socketService: mockSocketService,
        );
      },
      seed: () => ChatState(
        transactionId: 'tx_100',
        messages: [tMessage2],
      ),
      act: (bloc) => bloc.add(const ChatLoadMoreRequested()),
      expect: () => [
        ChatState(
          transactionId: 'tx_100',
          messages: [tMessage2, tMessage1],
        ),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'ChatSocketStatusChanged memperbarui isConnected',
      build: () => ChatBloc(
        repository: mockRepository,
        socketService: mockSocketService,
      ),
      act: (bloc) => bloc.add(const ChatSocketStatusChanged(isConnected: true)),
      expect: () => [
        const ChatState(isConnected: true),
      ],
    );
  });
}
