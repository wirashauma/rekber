import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/core/services/socket_service.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApiService;
  late SocketService socketService;

  setUp(() {
    mockApiService = MockApiService();
    when(() => mockApiService.getAccessToken()).thenAnswer((_) async => 'fake-token');
    socketService = SocketService(apiService: mockApiService);
  });

  group('SocketService Unit Tests', () {
    test('initial values and streams', () {
      expect(socketService.isConnected, isFalse);
      expect(socketService.onMessageReceived, isNotNull);
      expect(socketService.onMessageRead, isNotNull);
      expect(socketService.onTyping, isNotNull);
      expect(socketService.onConnectionState, isNotNull);
    });

    test('join and leave transaction room do not throw', () {
      expect(() => socketService.joinRoom('tx-123'), returnsNormally);
      expect(() => socketService.leaveRoom('tx-123'), returnsNormally);
    });

    test('sendTyping does not throw when disconnected', () {
      expect(
        () => socketService.sendTyping('tx-123', true),
        returnsNormally,
      );
    });

    test('dispose closes all stream controllers safely', () {
      expect(() => socketService.dispose(), returnsNormally);
    });
  });
}
