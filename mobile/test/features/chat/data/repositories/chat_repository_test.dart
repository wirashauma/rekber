import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/features/chat/data/repositories/chat_repository_impl.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApiService;
  late ChatRepositoryImpl repository;

  setUp(() {
    mockApiService = MockApiService();
    repository = ChatRepositoryImpl(apiService: mockApiService);
  });

  group('ChatRepositoryImpl Unit Tests', () {
    test('getMessages parses list of messages', () async {
      when(() => mockApiService.get(any())).thenAnswer((_) async => {
            'data': [
              {
                'id': 'msg-1',
                'transactionId': 'tx-1',
                'type': 'TEXT',
                'body': 'Halo gan',
                'createdAt': '2026-05-10T10:00:00.000Z',
              }
            ]
          });

      final result = await repository.getMessages('tx-1');
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('should be right'), (list) {
        expect(list.length, equals(1));
        expect(list.first.body, equals('Halo gan'));
      });
    });

    test('sendMessage sends text message and returns ChatMessageEntity', () async {
      when(() => mockApiService.post('/transactions/tx-1/messages', {
            'type': 'TEXT',
            'body': 'Siap kirim',
          })).thenAnswer((_) async => {
            'data': {
              'id': 'msg-2',
              'transactionId': 'tx-1',
              'type': 'TEXT',
              'body': 'Siap kirim',
              'createdAt': '2026-05-10T10:05:00.000Z',
            }
          });

      final result = await repository.sendMessage('tx-1', type: 'TEXT', body: 'Siap kirim');
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('should be right'), (entity) {
        expect(entity.id, equals('msg-2'));
        expect(entity.body, equals('Siap kirim'));
      });
    });

    test('markAsRead posts to read endpoint', () async {
      when(() => mockApiService.post('/transactions/tx-1/messages/read', {}))
          .thenAnswer((_) async => {'success': true});

      final result = await repository.markAsRead('tx-1');
      expect(result.isRight(), isTrue);
    });

    test('handles ApiException gracefully', () async {
      when(() => mockApiService.get(any())).thenThrow(ApiException(
        statusCode: 500,
        message: 'Server error',
      ));

      final result = await repository.getMessages('tx-1');
      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure.message, equals('Server error'));
      }, (_) => fail('should be left'));
    });

    test('uploadChatImage posts multipart and returns fileId', () async {
      when(() => mockApiService.postMultipart(
            '/files',
            fieldName: 'file',
            filePath: any(named: 'filePath'),
            fields: {'purpose': 'CHAT_IMAGE'},
          )).thenAnswer((_) async => {
            'data': {'id': 'chat-img-1'}
          });

      final result = await repository.uploadChatImage('path/to/chat.png');
      expect(result.isRight(), isTrue);
      expect(result.getOrElse(() => ''), equals('chat-img-1'));
    });

    test('sendMessage handles generic exceptions gracefully', () async {
      when(() => mockApiService.post(any(), any()))
          .thenThrow(Exception('Connection lost'));

      final result = await repository.sendMessage('tx-1', type: 'TEXT', body: 'Halo');
      expect(result.isLeft(), isTrue);
    });
  });
}
