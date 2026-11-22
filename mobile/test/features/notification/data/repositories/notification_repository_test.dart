import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/features/notification/data/repositories/notification_repository_impl.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApiService;
  late NotificationRepositoryImpl repository;

  setUp(() {
    mockApiService = MockApiService();
    repository = NotificationRepositoryImpl(apiService: mockApiService);
  });

  group('NotificationRepositoryImpl Unit Tests', () {
    test('getNotifications parses list of notifications', () async {
      when(() => mockApiService.get(any())).thenAnswer((_) async => {
            'success': true,
            'data': [
              {
                'id': 'notif-1',
                'title': 'Pembayaran Diterima',
                'body': 'Pembeli telah membayar transaksi #1234',
                'type': 'TRANSACTION_PAID',
                'createdAt': '2026-05-10T10:00:00.000Z',
              }
            ]
          });

      final result = await repository.getNotifications();
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('should be right'), (list) {
        expect(list.length, equals(1));
        expect(list.first.title, equals('Pembayaran Diterima'));
      });
    });

    test('getUnreadCount returns correct count', () async {
      when(() => mockApiService.get('/notifications/unread-count'))
          .thenAnswer((_) async => {'success': true, 'data': {'unreadCount': 5}});

      final result = await repository.getUnreadCount();
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('should be right'), (count) {
        expect(count, equals(5));
      });
    });

    test('markAsRead and markAllAsRead post correctly', () async {
      when(() => mockApiService.post('/notifications/notif-1/read', {}))
          .thenAnswer((_) async => {
                'success': true,
                'data': {
                  'id': 'notif-1',
                  'title': 'Test',
                  'body': 'Body',
                  'type': 'INFO',
                  'readAt': '2026-05-10T10:05:00.000Z',
                  'createdAt': '2026-05-10T10:00:00.000Z',
                }
              });
      when(() => mockApiService.post('/notifications/read-all', {}))
          .thenAnswer((_) async => {'success': true});

      final readSingle = await repository.markAsRead('notif-1');
      final readAll = await repository.markAllAsRead();

      expect(readSingle.isRight(), isTrue);
      expect(readAll.isRight(), isTrue);
    });

    test('handles ApiException and generic errors gracefully', () async {
      when(() => mockApiService.get('/notifications'))
          .thenThrow(ApiException(statusCode: 500, message: 'Gagal'));
      when(() => mockApiService.get('/notifications/unread-count'))
          .thenThrow(Exception('Crash'));

      final notifRes = await repository.getNotifications();
      expect(notifRes.isLeft(), isTrue);

      final countRes = await repository.getUnreadCount();
      expect(countRes.isLeft(), isTrue);
    });
  });
}
