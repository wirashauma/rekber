import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';
import 'package:rekber/core/services/notification_service.dart';
import 'package:rekber/features/notification/domain/entities/notification_entity.dart';
import 'package:rekber/features/notification/domain/repositories/notification_repository.dart';
import 'package:rekber/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:rekber/features/notification/presentation/cubit/notification_state.dart';

class MockNotificationRepository extends Mock implements NotificationRepository {}

void main() {
  group('NotificationService - Deep Link Route Resolution', () {
    test('resolveRouteFromPayload mengembalikan /dispute/:id jika ada disputeId', () {
      final route = NotificationService.resolveRouteFromPayload({
        'disputeId': 'disp_abc123',
        'transactionId': 'tx_999',
      });
      expect(route, '/dispute/disp_abc123');
    });

    test('resolveRouteFromPayload mengembalikan /chat/:id jika ada chatId', () {
      final route = NotificationService.resolveRouteFromPayload({
        'chatId': 'chat_xyz',
      });
      expect(route, '/chat/chat_xyz');
    });

    test('resolveRouteFromPayload mengembalikan /chat/:txId jika type mengandung CHAT', () {
      final route = NotificationService.resolveRouteFromPayload({
        'transactionId': 'tx_room_555',
        'type': 'CHAT_MESSAGE',
      });
      expect(route, '/chat/tx_room_555');
    });

    test('resolveRouteFromPayload mengembalikan /transaction/:id untuk event transaksi umum', () {
      final route = NotificationService.resolveRouteFromPayload({
        'transactionId': 'tx_007',
        'type': 'TRANSACTION_PAID',
      });
      expect(route, '/transaction/tx_007');
    });

    test('resolveRouteFromPayload mengembalikan null jika data kosong', () {
      expect(NotificationService.resolveRouteFromPayload(null), isNull);
      expect(NotificationService.resolveRouteFromPayload({}), isNull);
    });
  });

  group('NotificationEntity - JSON Serialization', () {
    test('fromJson & toJson parsing dengan data payload lengkap', () {
      final json = {
        'id': 'notif_1',
        'userId': 'user_1',
        'type': 'TRANSACTION_SHIPPED',
        'title': 'Pesanan Telah Dikirim',
        'body': 'Penjual telah mengirimkan pesanan Anda.',
        'data': {
          'transactionId': 'tx_123',
          'courier': 'JNE',
        },
        'readAt': null,
        'createdAt': '2026-03-25T12:00:00.000Z',
      };

      final entity = NotificationEntity.fromJson(json);

      expect(entity.id, 'notif_1');
      expect(entity.type, 'TRANSACTION_SHIPPED');
      expect(entity.title, 'Pesanan Telah Dikirim');
      expect(entity.data['transactionId'], 'tx_123');
      expect(entity.isRead, false);

      final backToJson = entity.toJson();
      expect(backToJson['id'], 'notif_1');
      expect(backToJson['data']['courier'], 'JNE');
    });
  });

  group('NotificationCubit - Inbox & Unread Badge Management', () {
    late MockNotificationRepository mockRepo;
    late NotificationCubit cubit;

    final tNotif1 = NotificationEntity(
      id: 'notif_1',
      userId: 'user_1',
      type: 'TRANSACTION_PAID',
      title: 'Pembayaran Diterima',
      body: 'Dana telah diamankan di escrow.',
      data: const {'transactionId': 'tx_1'},
      readAt: null,
      createdAt: DateTime.parse('2026-03-25T10:00:00Z'),
    );

    final tNotif2 = NotificationEntity(
      id: 'notif_2',
      userId: 'user_1',
      type: 'TRANSACTION_COMPLETED',
      title: 'Transaksi Selesai',
      body: 'Dana diteruskan ke penjual.',
      data: const {'transactionId': 'tx_2'},
      readAt: DateTime.parse('2026-03-25T11:00:00Z'),
      createdAt: DateTime.parse('2026-03-25T10:30:00Z'),
    );

    setUp(() {
      mockRepo = MockNotificationRepository();
      cubit = NotificationCubit(repository: mockRepo);
    });

    tearDown(() {
      cubit.close();
    });

    blocTest<NotificationCubit, NotificationState>(
      'loadNotifications memancarkan [NotificationLoading, NotificationLoaded] dengan unreadCount',
      build: () {
        when(() => mockRepo.getNotifications(limit: any(named: 'limit')))
            .thenAnswer((_) async => Right([tNotif1, tNotif2]));
        when(() => mockRepo.getUnreadCount())
            .thenAnswer((_) async => const Right(1));
        return cubit;
      },
      act: (cubit) => cubit.loadNotifications(refresh: true),
      expect: () => [
        NotificationLoading(),
        NotificationLoaded(
          notifications: [tNotif1, tNotif2],
          unreadCount: 1,
          hasMore: false,
        ),
      ],
      verify: (_) {
        expect(cubit.unreadCount, 1);
      },
    );

    blocTest<NotificationCubit, NotificationState>(
      'markAsRead mengupdate status notifikasi dan menurunkan unread badge',
      build: () {
        when(() => mockRepo.markAsRead('notif_1'))
            .thenAnswer((_) async => Right(tNotif1.copyWith(readAt: DateTime.now())));
        return cubit;
      },
      seed: () => NotificationLoaded(
        notifications: [tNotif1],
        unreadCount: 1,
      ),
      act: (cubit) => cubit.markAsRead('notif_1'),
      verify: (_) {
        verify(() => mockRepo.markAsRead('notif_1')).called(1);
      },
    );

    blocTest<NotificationCubit, NotificationState>(
      'markAllAsRead mereset unreadCount ke 0',
      build: () {
        when(() => mockRepo.markAllAsRead())
            .thenAnswer((_) async => const Right(1));
        return cubit;
      },
      seed: () => NotificationLoaded(
        notifications: [tNotif1],
        unreadCount: 1,
      ),
      act: (cubit) => cubit.markAllAsRead(),
      expect: () => [
        predicate<NotificationState>((state) {
          if (state is NotificationLoaded) {
            return state.unreadCount == 0 &&
                state.notifications.isNotEmpty &&
                state.notifications.first.isRead;
          }
          return false;
        }),
      ],
      verify: (_) {
        expect(cubit.unreadCount, 0);
      },
    );
  });
}
