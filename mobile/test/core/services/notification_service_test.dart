import 'package:flutter_test/flutter_test.dart';
import 'package:rekber/core/services/notification_service.dart';

void main() {
  group('NotificationService - resolveRouteFromPayload', () {
    test('returns null when payload is null or empty', () {
      expect(NotificationService.resolveRouteFromPayload(null), isNull);
      expect(NotificationService.resolveRouteFromPayload({}), isNull);
    });

    test('resolves dispute route when disputeId exists', () {
      final route = NotificationService.resolveRouteFromPayload({
        'disputeId': 'disp-123',
      });
      expect(route, equals('/dispute/disp-123'));
    });

    test('resolves chat route when chatId exists', () {
      final route = NotificationService.resolveRouteFromPayload({
        'chatId': 'tx-456',
      });
      expect(route, equals('/chat/tx-456'));
    });

    test('resolves transaction route or chat route from transactionId', () {
      final txRoute = NotificationService.resolveRouteFromPayload({
        'transactionId': 'tx-789',
        'type': 'TRANSACTION_PAID',
      });
      expect(txRoute, equals('/transaction/tx-789'));

      final chatRoute = NotificationService.resolveRouteFromPayload({
        'transactionId': 'tx-789',
        'type': 'CHAT_NEW_MESSAGE',
      });
      expect(chatRoute, equals('/chat/tx-789'));
    });
  });
}
