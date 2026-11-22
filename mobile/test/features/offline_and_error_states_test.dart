import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as gfonts;
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/features/auth/data/models/user_model.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_event.dart';
import 'package:rekber/features/auth/presentation/bloc/auth_state.dart';
import 'package:rekber/features/home/presentation/pages/home_page.dart';
import 'package:rekber/features/notification/presentation/cubit/notification_cubit.dart';
import 'package:rekber/features/notification/presentation/cubit/notification_state.dart';
import 'package:rekber/features/transaction/domain/entities/transaction_entity.dart';
import 'package:rekber/features/transaction/presentation/cubit/transaction_cubit.dart';
import 'package:rekber/features/transaction/presentation/cubit/transaction_state.dart';
import 'package:rekber/features/transaction/presentation/pages/riwayat_screen.dart';
import 'package:rekber/features/transaction/presentation/pages/transaction_detail_page.dart';
import 'package:rekber/features/wallet/domain/entities/bank_account_entity.dart';
import 'package:rekber/features/wallet/domain/entities/wallet_summary_entity.dart';
import 'package:rekber/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:rekber/features/wallet/presentation/cubit/wallet_state.dart';
import 'package:rekber/features/wallet/presentation/pages/tarik_dana_screen.dart';
import 'package:rekber/features/wallet/presentation/pages/top_up_screen.dart';
import 'package:rekber/injection_container.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}
class MockTransactionCubit extends MockCubit<TransactionState> implements TransactionCubit {}
class MockWalletCubit extends MockCubit<WalletState> implements WalletCubit {}
class MockNotificationCubit extends MockCubit<NotificationState> implements NotificationCubit {}
class MockApiService extends Mock implements ApiService {}

class _TestAssetManifest implements AssetManifest {
  final List<String> _assets;
  _TestAssetManifest(this._assets);

  @override
  List<String> listAssets() => _assets;

  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

void main() {
  late MockAuthBloc mockAuthBloc;
  late MockTransactionCubit mockTransactionCubit;
  late MockWalletCubit mockWalletCubit;
  late MockNotificationCubit mockNotificationCubit;
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

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;

    final candidates = [
      'C:/flutter/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
      'C:/flutter/flutter/bin/cache/artifacts/material_fonts/roboto-bold.ttf',
      'C:/Windows/Fonts/arial.ttf',
    ];
    Uint8List? fontBytes;
    for (final path in candidates) {
      final f = File(path);
      if (f.existsSync()) {
        fontBytes = f.readAsBytesSync();
        break;
      }
    }

    final kTransparentPng = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);

    if (fontBytes != null) {
      final families = [
        'SpaceGrotesk',
        'SpaceGrotesk_regular',
        'SpaceGrotesk_700',
        'SpaceGrotesk_500',
        'SpaceGrotesk_600',
        'SpaceGrotesk_300',
        'SpaceGrotesk_800',
        'SpaceGrotesk_900',
        'PlusJakartaSans',
      ];
      for (final fam in families) {
        final fl = FontLoader(fam);
        fl.addFont(Future.value(ByteData.view(fontBytes.buffer)));
        await fl.load();
      }

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (ByteData? message) async {
          if (message == null) return null;
          final key = utf8.decode(message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));
          if (key == 'AssetManifest.bin') {
            return const StandardMessageCodec().encodeMessage(<String, Object?>{});
          }
          if (key.contains('AssetManifest')) {
            return ByteData.view(Uint8List.fromList(utf8.encode('{}')).buffer);
          }
          if (key.endsWith('.png') || key.endsWith('.jpg') || key.endsWith('.jpeg') || key.endsWith('.webp')) {
            return ByteData.view(kTransparentPng.buffer);
          }
          if (key.endsWith('.ttf') || key.endsWith('.otf') || key.contains('google_fonts')) {
            return ByteData.view(fontBytes!.buffer);
          }
          return null;
        },
      );

      gfonts.assetManifest = _TestAssetManifest([
        'google_fonts/SpaceGrotesk-Regular.ttf',
        'google_fonts/SpaceGrotesk-Medium.ttf',
        'google_fonts/SpaceGrotesk-SemiBold.ttf',
        'google_fonts/SpaceGrotesk-Bold.ttf',
        'google_fonts/SpaceGrotesk-Light.ttf',
        'google_fonts/SpaceGrotesk.ttf',
      ]);
    }
  });

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    mockTransactionCubit = MockTransactionCubit();
    mockWalletCubit = MockWalletCubit();
    mockNotificationCubit = MockNotificationCubit();
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
      summary: WalletSummaryEntity(balance: 500000, heldBalance: 0),
    ));
    when(() => mockNotificationCubit.state).thenReturn(const NotificationLoaded(
      notifications: [],
      unreadCount: 0,
    ));

    when(() => mockWalletCubit.loadWalletData()).thenAnswer((_) async {});
    when(() => mockTransactionCubit.loadTransactions()).thenAnswer((_) async {});
    when(() => mockTransactionCubit.loadTransactionDetail(any())).thenAnswer((_) async {});
    when(() => mockNotificationCubit.loadNotifications()).thenAnswer((_) async {});
    when(() => mockNotificationCubit.loadUnreadCount()).thenAnswer((_) async {});
  });

  Widget wrapWithDevice(Widget child) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(440, 932),
          devicePixelRatio: 1.0,
        ),
        child: SizedBox(
          width: 440,
          height: 932,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: mockAuthBloc),
              BlocProvider<TransactionCubit>.value(value: mockTransactionCubit),
              BlocProvider<WalletCubit>.value(value: mockWalletCubit),
              BlocProvider<NotificationCubit>.value(value: mockNotificationCubit),
            ],
            child: child,
          ),
        ),
      ),
    );
  }

  group('A. State Error dan Offline pada HomePage', () {
    testWidgets('Menampilkan pesan error dan tombol retry ketika koneksi gagal', (tester) async {
      tester.view.physicalSize = const Size(440, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      when(() => mockTransactionCubit.state).thenReturn(
        const TransactionError(message: 'Koneksi terputus (Offline)'),
      );

      await tester.pumpWidget(wrapWithDevice(const HomePage()));
      await tester.pump();

      expect(find.text('Koneksi terputus (Offline)'), findsOneWidget);
      final retryButton = find.text('COBA LAGI');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump();

      verify(() => mockTransactionCubit.loadTransactions()).called(greaterThanOrEqualTo(1));
    });
  });

  group('B. State Error dan Offline pada RiwayatScreen', () {
    testWidgets('Menampilkan error card dan tombol Coba Lagi pada RiwayatScreen', (tester) async {
      tester.view.physicalSize = const Size(440, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      when(() => mockTransactionCubit.state).thenReturn(
        const TransactionError(message: 'Gagal memuat riwayat transaksi'),
      );

      await tester.pumpWidget(wrapWithDevice(const RiwayatScreen()));
      await tester.pump();

      expect(find.text('Gagal memuat riwayat transaksi'), findsOneWidget);
      final retryButton = find.text('COBA LAGI');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump();

      verify(() => mockTransactionCubit.loadTransactions()).called(greaterThanOrEqualTo(1));
    });
  });

  group('C. State Error dan Offline pada TransactionDetailPage', () {
    testWidgets('Menampilkan fallback layar dan tombol Kembali bila transaksi null', (tester) async {
      tester.view.physicalSize = const Size(440, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      when(() => mockTransactionCubit.state).thenReturn(
        const TransactionError(message: 'Data transaksi tidak ditemukan'),
      );
      when(() => mockTransactionCubit.currentDetail).thenReturn(null);

      await tester.pumpWidget(wrapWithDevice(const TransactionDetailPage(transactionId: 'tx-missing')));
      await tester.pumpAndSettle();

      expect(find.text('Transaksi tidak ditemukan.'), findsOneWidget);
      final backButton = find.text('KEMBALI');
      expect(backButton, findsOneWidget);
    });

    testWidgets('Menampilkan SnackBar saat terjadi TransactionActionFailure', (tester) async {
      final stateController = StreamController<TransactionState>.broadcast();
      whenListen(
        mockTransactionCubit,
        stateController.stream,
        initialState: TransactionDetailLoaded(
          transaction: TransactionEntity(
            id: 'tx-err',
            txCode: 'TRX-ERR',
            buyerId: 'user_1',
            sellerId: 'user_2',
            buyerName: 'Budi Pembeli',
            sellerName: 'Siti Penjual',
            amount: 150000,
            platformFee: 5000,
            buyerFee: 2500,
            sellerFee: 2500,
            feePayer: 'SPLIT',
            status: 'PENDING',
            description: 'Barang uji coba',
            createdAt: DateTime(2026, 5, 1),
          ),
        ),
      );

      await tester.pumpWidget(wrapWithDevice(const TransactionDetailPage(transactionId: 'tx-err')));
      await tester.pump();

      stateController.add(const TransactionActionFailure(message: 'Jaringan terputus, gagal memproses'));
      await tester.pumpAndSettle();

      expect(find.text('Gagal: Jaringan terputus, gagal memproses'), findsOneWidget);
      await stateController.close();
    });
  });

  group('D. State Error dan Offline pada TopUpScreen', () {
    testWidgets('Menampilkan SnackBar error ketika WalletActionFailure terjadi', (tester) async {
      final stateController = StreamController<WalletState>.broadcast();
      whenListen(
        mockWalletCubit,
        stateController.stream,
        initialState: const WalletLoaded(
          summary: WalletSummaryEntity(balance: 100000, heldBalance: 0),
        ),
      );

      await tester.pumpWidget(wrapWithDevice(const TopUpScreen()));
      await tester.pump();

      stateController.add(const WalletActionFailure(message: 'Gateway pembayaran sedang offline'));
      await tester.pumpAndSettle();

      expect(find.text('Gagal: Gateway pembayaran sedang offline'), findsOneWidget);
      await stateController.close();
    });
  });

  group('E. State Error dan Offline pada TarikDanaScreen', () {
    testWidgets('Menampilkan SnackBar error saat penarikan gagal karena offline', (tester) async {
      final stateController = StreamController<WalletState>.broadcast();
      whenListen(
        mockWalletCubit,
        stateController.stream,
        initialState: WalletLoaded(
          summary: const WalletSummaryEntity(balance: 500000, heldBalance: 0),
          bankAccounts: [
            BankAccountEntity(
              id: 'ba-1',
              bankCode: 'BCA',
              accountLast4: '1234',
              accountName: 'Budi Santoso',
              isDefault: true,
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
      );

      await tester.pumpWidget(wrapWithDevice(const TarikDanaScreen()));
      await tester.pump();

      stateController.add(const WalletActionFailure(message: 'Layanan bank sedang offline'));
      await tester.pumpAndSettle();

      expect(find.text('Layanan bank sedang offline'), findsOneWidget);
      await stateController.close();
    });

    testWidgets('Menampilkan Dialog KYC ketika WalletActionFailure mensyaratkan KYC', (tester) async {
      final stateController = StreamController<WalletState>.broadcast();
      whenListen(
        mockWalletCubit,
        stateController.stream,
        initialState: const WalletLoaded(
          summary: WalletSummaryEntity(balance: 500000, heldBalance: 0),
        ),
      );

      await tester.pumpWidget(wrapWithDevice(const TarikDanaScreen()));
      await tester.pump();

      stateController.add(const WalletActionFailure(
        message: 'Penarikan dana memerlukan verifikasi KYC yang telah disetujui.',
        isKycRequired: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Verifikasi KYC Diperlukan'), findsOneWidget);
      expect(find.textContaining('Penarikan dana memerlukan verifikasi KYC yang telah disetujui.'), findsOneWidget);
      expect(find.text('Verifikasi Sekarang'), findsOneWidget);
      await stateController.close();
    });
  });
}
