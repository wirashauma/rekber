import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/features/auth/data/models/user_model.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_event.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_state.dart';
import 'package:rekber/features/auth/presentation/pages/login_page.dart';
import 'package:rekber/features/chat/domain/entities/chat_message_entity.dart';
import 'package:rekber/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:rekber/features/chat/presentation/pages/chat_room_page.dart';
import 'package:rekber/features/dispute/presentation/cubit/dispute_cubit.dart';
import 'package:rekber/features/dispute/presentation/cubit/dispute_state.dart';
import 'package:rekber/features/home/presentation/pages/home_page.dart';
import 'package:rekber/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:rekber/features/notification/presentation/cubit/notification_state.dart';
import 'package:rekber/features/transaction/domain/entities/transaction_entity.dart';
import 'package:rekber/features/transaction/presentation/cubit/transaction_cubit.dart';
import 'package:rekber/features/transaction/presentation/cubit/transaction_state.dart';
import 'package:rekber/features/transaction/presentation/pages/transaction_detail_page.dart';
import 'package:rekber/features/wallet/domain/entities/wallet_summary_entity.dart';
import 'package:rekber/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:rekber/features/wallet/presentation/cubit/wallet_state.dart';
import 'package:rekber/features/wallet/presentation/pages/top_up_screen.dart';
import 'package:rekber/injection_container.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
class MockTransactionCubit extends MockCubit<TransactionState> implements TransactionCubit {}
class MockWalletCubit extends MockCubit<WalletState> implements WalletCubit {}
class MockNotificationCubit extends MockCubit<NotificationState> implements NotificationCubit {}
class MockChatBloc extends MockBloc<ChatEvent, ChatState> implements ChatBloc {}
class MockDisputeCubit extends MockCubit<DisputeState> implements DisputeCubit {}
class MockApiService extends Mock implements ApiService {}

class _FakeFontHttpOverrides extends HttpOverrides {
  final Uint8List fontBytes;
  _FakeFontHttpOverrides(this.fontBytes);

  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient(fontBytes);
}

class _FakeHttpClient extends Fake implements HttpClient {
  final Uint8List fontBytes;
  _FakeHttpClient(this.fontBytes);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest(fontBytes);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _FakeHttpClientRequest(fontBytes);
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  final Uint8List fontBytes;
  _FakeHttpClientRequest(this.fontBytes);

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = 0;

  @override
  bool persistentConnection = false;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  void add(List<int> data) {}

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  Future flush() async {}

  @override
  void write(Object? obj) {}

  @override
  void writeln([Object? obj = '']) {}

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse(fontBytes);
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name, () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name] = [value.toString()];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  List<String>? operator [](String name) => _headers[name];

  @override
  String? value(String name) => _headers[name]?.isNotEmpty == true ? _headers[name]!.first : null;
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  final Uint8List fontBytes;
  _FakeHttpClientResponse(this.fontBytes);

  @override
  int get statusCode => 200;

  @override
  int get contentLength => fontBytes.length;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  String get reasonPhrase => 'OK';

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(fontBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  late MockAuthBloc mockAuthBloc;
  late MockTransactionCubit mockTransactionCubit;
  late MockWalletCubit mockWalletCubit;
  late MockNotificationCubit mockNotificationCubit;
  late MockChatBloc mockChatBloc;
  late MockDisputeCubit mockDisputeCubit;
  late MockApiService mockApiService;

  final tUser = UserModel(
    id: 'user_1',
    email: 'budi@test.com',
    fullName: 'Budi Santoso',
    role: 'USER',
    kycStatus: 'APPROVED',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  void Function(FlutterErrorDetails)? originalOnError;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    final candidates = [
      'C:/Windows/Fonts/arial.ttf',
      'C:/flutter/flutter/bin/cache/artifacts/material_fonts/roboto-bold.ttf',
    ];
    for (final path in candidates) {
      final f = File(path);
      if (f.existsSync()) {
        HttpOverrides.global = _FakeFontHttpOverrides(f.readAsBytesSync());
        break;
      }
    }

    originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.toString().contains('overflowed by')) {
        return;
      }
      originalOnError?.call(details);
    };
  });

  tearDownAll(() {
    FlutterError.onError = originalOnError;
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    mockTransactionCubit = MockTransactionCubit();
    mockWalletCubit = MockWalletCubit();
    mockNotificationCubit = MockNotificationCubit();
    mockChatBloc = MockChatBloc();
    mockDisputeCubit = MockDisputeCubit();
    mockApiService = MockApiService();

    if (sl.isRegistered<ApiService>()) {
      sl.unregister<ApiService>();
    }
    sl.registerLazySingleton<ApiService>(() => mockApiService);

    when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(
      user: tUser,
      activeRole: 'BUYER',
    ));
    when(() => mockWalletCubit.state).thenReturn(const WalletLoaded(
      summary: WalletSummaryEntity(balance: 1500000, heldBalance: 300000),
    ));
    when(() => mockNotificationCubit.state).thenReturn(const NotificationLoaded(
      notifications: [],
      unreadCount: 3,
    ));
    when(() => mockChatBloc.state).thenReturn(ChatState(
      transactionId: 'tx-100',
      isConnected: true,
      messages: [
        ChatMessageEntity(
          id: 'msg-1',
          transactionId: 'tx-100',
          senderId: 'user_1',
          type: 'TEXT',
          body: 'Halo, barang sudah dikirim?',
          createdAt: DateTime(2026, 5, 10, 10, 0),
          isRead: true,
        ),
      ],
    ));
    when(() => mockDisputeCubit.state).thenReturn(DisputeInitial());
  });

  Widget wrapWithDevice(Widget child) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          devicePixelRatio: 1.0,
        ),
        child: SizedBox(
          width: 390,
          height: 844,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: mockAuthBloc),
              BlocProvider<TransactionCubit>.value(value: mockTransactionCubit),
              BlocProvider<WalletCubit>.value(value: mockWalletCubit),
              BlocProvider<NotificationCubit>.value(value: mockNotificationCubit),
              BlocProvider<ChatBloc>.value(value: mockChatBloc),
              BlocProvider<DisputeCubit>.value(value: mockDisputeCubit),
            ],
            child: child,
          ),
        ),
      ),
    );
  }

  TransactionEntity createDummyTx(String status) {
    return TransactionEntity(
      id: 'tx-100',
      txCode: 'TRX-998877',
      buyerId: 'user_1',
      sellerId: 'user_2',
      buyerName: 'Budi Santoso',
      sellerName: 'Siti Aminah',
      amount: 250000,
      platformFee: 5000,
      buyerFee: 2500,
      sellerFee: 2500,
      feePayer: 'SPLIT',
      status: status,
      description: 'Jersey Vintage Original 1998',
      createdAt: DateTime(2026, 5, 10, 9, 30),
      courier: status == 'SHIPPED' ? 'JNE' : null,
      trackingNumber: status == 'SHIPPED' ? 'JNE987654321' : null,
      autoReleaseAt: status == 'SHIPPED' ? DateTime(2026, 5, 12, 9, 30) : null,
    );
  }

  testWidgets('Golden Test - 1. Login Page', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    when(() => mockAuthBloc.state).thenReturn(AuthUnauthenticated());

    await tester.pumpWidget(wrapWithDevice(const LoginPage()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/01_login_page.png'),
    );
  });

  testWidgets('Golden Test - 2. Home Page', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final tx = createDummyTx('PAID');
    when(() => mockTransactionCubit.state).thenReturn(TransactionListLoaded(
      transactions: [tx],
    ));

    await tester.pumpWidget(wrapWithDevice(const HomePage()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/02_home_page.png'),
    );
  });

  testWidgets('Golden Test - 3. Transaction Detail (PENDING)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final txPending = createDummyTx('PENDING');
    when(() => mockTransactionCubit.state).thenReturn(
      TransactionDetailLoaded(transaction: txPending),
    );

    await tester.pumpWidget(wrapWithDevice(
      const TransactionDetailPage(transactionId: 'tx-100'),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/03_tx_detail_pending.png'),
    );
  });

  testWidgets('Golden Test - 4. Transaction Detail (PAID)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final txPaid = createDummyTx('PAID');
    when(() => mockTransactionCubit.state).thenReturn(
      TransactionDetailLoaded(transaction: txPaid),
    );

    await tester.pumpWidget(wrapWithDevice(
      const TransactionDetailPage(transactionId: 'tx-100'),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/04_tx_detail_paid.png'),
    );
  });

  testWidgets('Golden Test - 5. Transaction Detail (SHIPPED)', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final txShipped = createDummyTx('SHIPPED');
    when(() => mockTransactionCubit.state).thenReturn(
      TransactionDetailLoaded(transaction: txShipped),
    );

    await tester.pumpWidget(wrapWithDevice(
      const TransactionDetailPage(transactionId: 'tx-100'),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/05_tx_detail_shipped.png'),
    );
  });

  testWidgets('Golden Test - 6. TopUp Screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(wrapWithDevice(const TopUpScreen()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/06_top_up_screen.png'),
    );
  });

  testWidgets('Golden Test - 7. Form Sengketa Modal', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final txPaid = createDummyTx('PAID');
    when(() => mockTransactionCubit.state).thenReturn(
      TransactionDetailLoaded(transaction: txPaid),
    );

    await tester.pumpWidget(wrapWithDevice(
      const TransactionDetailPage(transactionId: 'tx-100'),
    ));
    await tester.pumpAndSettle();

    // Scroll to and tap 'AJUKAN SENGKETA' button to open the dispute bottomsheet
    final disputeBtn = find.text('AJUKAN SENGKETA');
    await tester.ensureVisible(disputeBtn);
    await tester.pumpAndSettle();
    expect(disputeBtn, findsOneWidget);
    await tester.tap(disputeBtn);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/07_dispute_form_modal.png'),
    );
  });

  testWidgets('Golden Test - 8. Chat Room Page', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(wrapWithDevice(
      const ChatRoomPage(transactionId: 'tx-100'),
    ));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/08_chat_room_page.png'),
    );
  });
}
