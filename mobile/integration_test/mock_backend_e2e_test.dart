import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rekber/core/services/api_service.dart';

/// In-Process Mock Backend Server for E2E Flow Testing
class MockBackendServer {
  late HttpServer _server;
  int get port => _server.port;

  // In-memory state for mock backend
  int sellerBalance = 0;
  final Map<String, Map<String, dynamic>> transactions = {};
  final Map<String, Map<String, dynamic>> disputes = {};

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest req) async {
    final path = req.uri.path;
    final method = req.method;

    String bodyStr = '';
    if (method == 'POST' || method == 'PUT' || method == 'PATCH') {
      bodyStr = await utf8.decodeStream(req);
    }
    Map<String, dynamic> bodyJson = {};
    if (bodyStr.isNotEmpty) {
      try {
        bodyJson = jsonDecode(bodyStr) as Map<String, dynamic>;
      } catch (_) {}
    }

    req.response.headers.contentType = ContentType.json;

    // 1. Auth Login
    if (method == 'POST' && path == '/api/auth/login') {
      final email = bodyJson['email'] ?? '';
      final isBuyer = email.toString().contains('buyer') || email.toString().contains('pembeli');
      final userId = isBuyer ? 'user_buyer' : 'user_seller';
      final userName = isBuyer ? 'Budi Pembeli' : 'Siti Penjual';

      req.response.statusCode = 200;
      req.response.write(jsonEncode({
        'data': {
          'accessToken': '${userId}_token',
          'refreshToken': '${userId}_refresh',
          'user': {
            'id': userId,
            'email': email,
            'fullName': userName,
            'role': 'USER',
            'kycStatus': 'APPROVED',
            'isActive': true,
          },
        },
      }));
      await req.response.close();
      return;
    }

    // 2. Wallet Balance
    if (method == 'GET' && path == '/api/wallet') {
      req.response.statusCode = 200;
      req.response.write(jsonEncode({
        'data': {
          'balance': sellerBalance,
          'heldBalance': 0,
        },
      }));
      await req.response.close();
      return;
    }

    // 3. Create Transaction Room
    if (method == 'POST' && path == '/api/transactions') {
      final txId = 'tx_${DateTime.now().millisecondsSinceEpoch}';
      final amount = bodyJson['amount'] ?? 200000;
      final feePayer = bodyJson['feePayer'] ?? 'SELLER';
      const platformFee = 5000;
      final sellerFee = feePayer == 'SELLER' ? platformFee : 0;
      final buyerFee = feePayer == 'BUYER' ? platformFee : 0;

      final tx = {
        'id': txId,
        'txCode': 'TRX-${txId.substring(txId.length - 6)}',
        'buyerId': 'user_buyer',
        'sellerId': 'user_seller',
        'buyerName': 'Budi Pembeli',
        'sellerName': 'Siti Penjual',
        'amount': amount,
        'platformFee': platformFee,
        'buyerFee': buyerFee,
        'sellerFee': sellerFee,
        'feePayer': feePayer,
        'status': 'PENDING',
        'description': bodyJson['description'] ?? 'Barang Uji Coba E2E',
        'createdAt': DateTime.now().toIso8601String(),
      };
      transactions[txId] = tx;

      req.response.statusCode = 201;
      req.response.write(jsonEncode({'data': tx}));
      await req.response.close();
      return;
    }

    // 4. Pay Transaction
    final payMatch = RegExp(r'^/api/transactions/([^/]+)/pay$').firstMatch(path);
    if (method == 'POST' && payMatch != null) {
      final txId = payMatch.group(1)!;
      final tx = transactions[txId];
      if (tx != null) {
        tx['status'] = 'PAID';
        req.response.statusCode = 200;
        req.response.write(jsonEncode({'data': tx}));
      } else {
        req.response.statusCode = 404;
        req.response.write(jsonEncode({'message': 'Transaksi tidak ditemukan'}));
      }
      await req.response.close();
      return;
    }

    // 5. Submit Shipment Proof
    final shipMatch = RegExp(r'^/api/transactions/([^/]+)/shipment$').firstMatch(path);
    if (method == 'POST' && shipMatch != null) {
      final txId = shipMatch.group(1)!;
      final tx = transactions[txId];
      if (tx != null) {
        tx['status'] = 'SHIPPED';
        tx['courier'] = bodyJson['courier'] ?? 'JNE';
        tx['trackingNumber'] = bodyJson['trackingNumber'] ?? 'JNE987654321';
        tx['autoReleaseAt'] = DateTime.now().add(const Duration(days: 2)).toIso8601String();
        req.response.statusCode = 200;
        req.response.write(jsonEncode({'data': tx}));
      } else {
        req.response.statusCode = 404;
        req.response.write(jsonEncode({'message': 'Transaksi tidak ditemukan'}));
      }
      await req.response.close();
      return;
    }

    // 6. Confirm Received (Release Escrow to Seller)
    final confirmMatch = RegExp(r'^/api/transactions/([^/]+)/confirm$').firstMatch(path);
    if (method == 'POST' && confirmMatch != null) {
      final txId = confirmMatch.group(1)!;
      final tx = transactions[txId];
      if (tx != null) {
        tx['status'] = 'COMPLETED';
        final int amount = tx['amount'] as int;
        final int sellerFee = tx['sellerFee'] as int;
        // Saldo penjual bertambah
        sellerBalance += (amount - sellerFee);

        req.response.statusCode = 200;
        req.response.write(jsonEncode({'data': tx}));
      } else {
        req.response.statusCode = 404;
        req.response.write(jsonEncode({'message': 'Transaksi tidak ditemukan'}));
      }
      await req.response.close();
      return;
    }

    // 7. Open Dispute
    final disputeMatch = RegExp(r'^/api/transactions/([^/]+)/dispute$').firstMatch(path);
    if (method == 'POST' && disputeMatch != null) {
      final txId = disputeMatch.group(1)!;
      final tx = transactions[txId];
      if (tx != null) {
        tx['status'] = 'DISPUTED';
        final dispId = 'disp_${DateTime.now().millisecondsSinceEpoch}';
        final disp = {
          'id': dispId,
          'transactionId': txId,
          'status': 'OPEN',
          'reason': bodyJson['reason'] ?? 'NOT_RECEIVED',
          'description': bodyJson['description'] ?? '',
          'openedById': 'user_buyer',
          'createdAt': DateTime.now().toIso8601String(),
        };
        disputes[dispId] = disp;

        req.response.statusCode = 201;
        req.response.write(jsonEncode({'data': disp}));
      } else {
        req.response.statusCode = 404;
        req.response.write(jsonEncode({'message': 'Transaksi tidak ditemukan'}));
      }
      await req.response.close();
      return;
    }

    // 8. Get Transaction Detail
    final txDetailMatch = RegExp(r'^/api/transactions/([^/]+)$').firstMatch(path);
    if (method == 'GET' && txDetailMatch != null) {
      final txId = txDetailMatch.group(1)!;
      final tx = transactions[txId];
      if (tx != null) {
        req.response.statusCode = 200;
        req.response.write(jsonEncode({'data': tx}));
      } else {
        req.response.statusCode = 404;
        req.response.write(jsonEncode({'message': 'Transaksi tidak ditemukan'}));
      }
      await req.response.close();
      return;
    }

    // 9. Get Dispute Detail
    final dispDetailMatch = RegExp(r'^/api/disputes/([^/]+)$').firstMatch(path);
    if (method == 'GET' && dispDetailMatch != null) {
      final dispId = dispDetailMatch.group(1)!;
      final disp = disputes[dispId];
      if (disp != null) {
        req.response.statusCode = 200;
        req.response.write(jsonEncode({'data': disp}));
      } else {
        req.response.statusCode = 404;
        req.response.write(jsonEncode({'message': 'Dispute tidak ditemukan'}));
      }
      await req.response.close();
      return;
    }

    // Fallback 404
    req.response.statusCode = 404;
    req.response.write(jsonEncode({'message': 'Not found'}));
    await req.response.close();
  }
}

/// HttpOverrides to redirect all ApiService requests to in-process mock server
class _MockBackendHttpOverrides extends HttpOverrides {
  final int mockPort;
  _MockBackendHttpOverrides(this.mockPort);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _RedirectHttpClient(super.createHttpClient(context), mockPort);
  }
}

class _RedirectHttpClient implements HttpClient {
  final HttpClient _inner;
  final int _targetPort;
  _RedirectHttpClient(this._inner, this._targetPort);

  Uri _redirect(Uri url) {
    if (url.host == 'localhost' || url.host == '127.0.0.1' || url.host == '10.0.2.2') {
      return url.replace(host: '127.0.0.1', port: _targetPort);
    }
    return url;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _inner.getUrl(_redirect(url));

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _inner.postUrl(_redirect(url));

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _inner.putUrl(_redirect(url));

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _inner.deleteUrl(_redirect(url));

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _inner.patchUrl(_redirect(url));

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _inner.headUrl(_redirect(url));

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => _inner.openUrl(method, _redirect(url));

  @override
  dynamic noSuchMethod(Invocation invocation) => _inner.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  late MockBackendServer mockServer;
  late ApiService buyerApi;
  late ApiService sellerApi;

  setUpAll(() async {
    mockServer = MockBackendServer();
    await mockServer.start();

    HttpOverrides.global = _MockBackendHttpOverrides(mockServer.port);
    buyerApi = ApiService();
    sellerApi = ApiService();
  });

  tearDownAll(() async {
    HttpOverrides.global = null;
    await mockServer.stop();
  });

  group('Skenario 1: Alur Lengkap Escrow Transaksi E2E', () {
    late String transactionId;

    test('1. Login Pembeli & Login Penjual', () async {
      // Pembeli login
      final buyerLogin = await buyerApi.post('/auth/login', {
        'email': 'pembeli@test.com',
        'password': 'password123',
      });
      expect(buyerLogin['data']['accessToken'], isNotNull);
      expect(buyerLogin['data']['user']['fullName'], equals('Budi Pembeli'));
      await buyerApi.saveToken(buyerLogin['data']['accessToken']);

      // Penjual login
      final sellerLogin = await sellerApi.post('/auth/login', {
        'email': 'penjual@test.com',
        'password': 'password123',
      });
      expect(sellerLogin['data']['accessToken'], isNotNull);
      expect(sellerLogin['data']['user']['fullName'], equals('Siti Penjual'));
      await sellerApi.saveToken(sellerLogin['data']['accessToken']);
    });

    test('2. Cek Saldo Awal Penjual adalah Rp 0', () async {
      final wallet = await sellerApi.get('/wallet');
      expect(wallet['data']['balance'], equals(0));
    });

    test('3. Pembeli Buat Room Transaksi (Status: PENDING)', () async {
      final createRes = await buyerApi.post('/transactions', {
        'amount': 200000,
        'feePayer': 'SELLER',
        'description': 'Laptop Second E2E',
      });

      expect(createRes['data']['id'], isNotNull);
      expect(createRes['data']['status'], equals('PENDING'));
      expect(createRes['data']['amount'], equals(200000));
      expect(createRes['data']['sellerFee'], equals(5000));
      transactionId = createRes['data']['id'].toString();
    });

    test('4. Pembeli Bayar Transaksi (Status: PAID)', () async {
      final payRes = await buyerApi.post('/transactions/$transactionId/pay', {
        'method': 'BALANCE',
      });

      expect(payRes['data']['id'], equals(transactionId));
      expect(payRes['data']['status'], equals('PAID'));
    });

    test('5. Penjual Kirim Bukti Resi Pengiriman (Status: SHIPPED)', () async {
      final shipRes = await sellerApi.post('/transactions/$transactionId/shipment', {
        'courier': 'JNE',
        'trackingNumber': 'JNE987654321',
      });

      expect(shipRes['data']['id'], equals(transactionId));
      expect(shipRes['data']['status'], equals('SHIPPED'));
      expect(shipRes['data']['courier'], equals('JNE'));
      expect(shipRes['data']['trackingNumber'], equals('JNE987654321'));
    });

    test('6. Pembeli Konfirmasi Barang Diterima (Status: COMPLETED)', () async {
      final confirmRes = await buyerApi.post('/transactions/$transactionId/confirm', {});

      expect(confirmRes['data']['id'], equals(transactionId));
      expect(confirmRes['data']['status'], equals('COMPLETED'));
    });

    test('7. Saldo Penjual Bertambah Sesuai Nominal Bersih (Rp 195.000)', () async {
      final wallet = await sellerApi.get('/wallet');
      // Saldo awal 0 + 200.000 - 5.000 (sellerFee) = 195.000
      expect(wallet['data']['balance'], equals(195000));
    });
  });

  group('Skenario 2: Pembeli Buka Sengketa', () {
    late String disputeTxId;
    late String disputeId;

    test('1. Pembeli Membuat dan Membayar Transaksi Baru', () async {
      final createRes = await buyerApi.post('/transactions', {
        'amount': 350000,
        'feePayer': 'SPLIT',
        'description': 'Kamera Mirrorless Bekas',
      });
      disputeTxId = createRes['data']['id'].toString();

      final payRes = await buyerApi.post('/transactions/$disputeTxId/pay', {});
      expect(payRes['data']['status'], equals('PAID'));
    });

    test('2. Penjual Mengirimkan Paket', () async {
      final shipRes = await sellerApi.post('/transactions/$disputeTxId/shipment', {
        'courier': 'SiCepat',
        'trackingNumber': 'SC1234567890',
      });
      expect(shipRes['data']['status'], equals('SHIPPED'));
    });

    test('3. Pembeli Membuka Sengketa karena Barang Tidak Diterima', () async {
      final disputeRes = await buyerApi.post('/transactions/$disputeTxId/dispute', {
        'reason': 'NOT_RECEIVED',
        'description': 'Paket tidak kunjung tiba melebihi estimasi pengiriman 7 hari kerja.',
      });

      expect(disputeRes['data']['id'], isNotNull);
      expect(disputeRes['data']['transactionId'], equals(disputeTxId));
      expect(disputeRes['data']['status'], equals('OPEN'));
      expect(disputeRes['data']['reason'], equals('NOT_RECEIVED'));
      disputeId = disputeRes['data']['id'].toString();
    });

    test('4. Status Transaksi Menjadi DISPUTED', () async {
      final txRes = await buyerApi.get('/transactions/$disputeTxId');
      expect(txRes['data']['status'], equals('DISPUTED'));
    });

    test('5. Detail Sengketa Terdaftar dan Terbuka (Status: OPEN)', () async {
      final dispRes = await buyerApi.get('/disputes/$disputeId');
      expect(dispRes['data']['id'], equals(disputeId));
      expect(dispRes['data']['status'], equals('OPEN'));
      expect(dispRes['data']['reason'], equals('NOT_RECEIVED'));
      expect(dispRes['data']['openedById'], equals('user_buyer'));
    });
  });
}
