import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/core/errors/failures.dart';
import 'package:rekber/features/transaction/data/repositories/transaction_repository_impl.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApiService;
  late TransactionRepositoryImpl repository;

  setUp(() {
    mockApiService = MockApiService();
    repository = TransactionRepositoryImpl(apiService: mockApiService);
  });

  group('TransactionRepository - Parsing Fixtures', () {
    test('getTransactions parses JSON backend list accurately', () async {
      final fixtureResponse = {
        'success': true,
        'message': 'Daftar transaksi berhasil diambil.',
        'data': [
          {
            'id': 'tx-uuid-1',
            'txCode': 'TRX-123456',
            'buyerId': 'buyer-uuid',
            'sellerId': 'seller-uuid',
            'amount': 250000,
            'platformFee': 5000,
            'buyerFee': 2500,
            'sellerFee': 2500,
            'feePayer': 'SPLIT',
            'status': 'PENDING',
            'description': 'Jersey Bola Original',
            'createdAt': '2026-03-25T12:00:00.000Z',
            'buyer': {'id': 'buyer-uuid', 'fullName': 'Budi', 'email': 'budi@test.com'},
            'seller': {'id': 'seller-uuid', 'fullName': 'Siti', 'email': 'siti@test.com'},
          }
        ]
      };

      when(() => mockApiService.get('/transactions'))
          .thenAnswer((_) async => fixtureResponse);

      final result = await repository.getTransactions();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Harus sukses'),
        (list) {
          expect(list.length, 1);
          final item = list.first;
          expect(item.id, 'tx-uuid-1');
          expect(item.txCode, 'TRX-123456');
          expect(item.amount, 250000);
          expect(item.totalAmount, 252500);
          expect(item.sellerReceives, 247500);
          expect(item.status, 'PENDING');
          expect(item.buyerName, 'Budi');
          expect(item.sellerName, 'Siti');
        },
      );
    });

    test('updateStatus handles 409 Conflict properly as ConflictFailure', () async {
      when(() => mockApiService.put('/transactions/tx-1/status', {'status': 'PAID'}))
          .thenThrow(ApiException(statusCode: 409, message: 'Status tidak sesuai.'));

      final result = await repository.updateStatus(id: 'tx-1', status: 'PAID');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ConflictFailure>());
          expect(failure.message, 'Status tidak sesuai.');
        },
        (_) => fail('Harus gagal 409'),
      );
    });

    test('getPublicConfig parses backend configuration accurately', () async {
      final fixtureResponse = {
        'success': true,
        'data': {
          'fee_percent': 0.02,
          'fee_min': 1000,
          'fee_payer_default': 'SPLIT',
          'withdraw_min': 50000,
          'withdraw_fee': 0,
          'max_transaction_amount': 5000000,
        }
      };

      when(() => mockApiService.get('/config/public'))
          .thenAnswer((_) async => fixtureResponse);

      final result = await repository.getPublicConfig();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Harus sukses'),
        (cfg) {
          expect(cfg.feePercent, 0.02);
          expect(cfg.feeMin, 1000);
          expect(cfg.feePayerDefault, 'SPLIT');
          expect(cfg.calculateFee(50000), 1000);
          expect(cfg.calculateFee(100000), 2000);
        },
      );
    });

    test('getTransactionById parses single transaction', () async {
      when(() => mockApiService.get('/transactions/tx-123')).thenAnswer((_) async => {
        'success': true,
        'data': {
          'id': 'tx-123',
          'txCode': 'TRX-123',
          'buyerId': 'buyer-1',
          'sellerId': 'seller-1',
          'amount': 100000,
          'platformFee': 2000,
          'status': 'PAID',
          'createdAt': '2026-03-25T12:00:00.000Z',
        }
      });
      final res = await repository.getTransactionById('tx-123');
      expect(res.isRight(), isTrue);
    });

    test('getTransactionByCode parses single transaction', () async {
      when(() => mockApiService.get('/transactions/code/TRX-123')).thenAnswer((_) async => {
        'success': true,
        'data': {
          'id': 'tx-123',
          'txCode': 'TRX-123',
          'buyerId': 'buyer-1',
          'sellerId': 'seller-1',
          'amount': 100000,
          'platformFee': 2000,
          'status': 'PAID',
          'createdAt': '2026-03-25T12:00:00.000Z',
        }
      });
      final res = await repository.getTransactionByCode('TRX-123');
      expect(res.isRight(), isTrue);
    });

    test('createTransaction sends body and returns TransactionEntity', () async {
      when(() => mockApiService.post('/transactions', any())).thenAnswer((_) async => {
        'success': true,
        'data': {
          'id': 'tx-new',
          'txCode': 'TRX-999',
          'buyerId': 'buyer-1',
          'sellerId': 'seller-1',
          'amount': 50000,
          'platformFee': 1000,
          'status': 'PENDING',
          'createdAt': '2026-03-25T12:00:00.000Z',
        }
      });
      final res = await repository.createTransaction(
        amount: 50000,
        itemDescription: 'Item test',
        feePayer: 'BUYER',
      );
      expect(res.isRight(), isTrue);
    });

    test('submitShipment sends shipment details and returns entity', () async {
      when(() => mockApiService.post('/transactions/tx-1/shipment', any())).thenAnswer((_) async => {
        'success': true,
        'data': {
          'id': 'tx-1',
          'txCode': 'TRX-1',
          'buyerId': 'buyer-1',
          'sellerId': 'seller-1',
          'amount': 50000,
          'platformFee': 1000,
          'status': 'SHIPPED',
          'createdAt': '2026-03-25T12:00:00.000Z',
        }
      });
      final res = await repository.submitShipment(
        id: 'tx-1',
        courier: 'JNE',
        trackingNumber: '12345',
        fileIds: ['file-1'],
      );
      expect(res.isRight(), isTrue);
    });

    test('handles exceptions and 409 conflict gracefully across methods', () async {
      when(() => mockApiService.get('/transactions/tx-err'))
          .thenThrow(ApiException(statusCode: 409, message: 'Conflict error'));
      when(() => mockApiService.post('/transactions', any()))
          .thenThrow(Exception('Network down'));

      final errRes = await repository.getTransactionById('tx-err');
      expect(errRes.isLeft(), isTrue);
      expect(errRes.fold((l) => l, (_) => null), isA<ConflictFailure>());

      final netRes = await repository.createTransaction(
        amount: 10000,
        itemDescription: 'desc',
        feePayer: 'BUYER',
      );
      expect(netRes.isLeft(), isTrue);
    });

    test('uploadShipmentProof works properly', () async {
      when(() => mockApiService.postMultipart(
            '/files',
            fieldName: 'file',
            filePath: any(named: 'filePath'),
            fields: {'purpose': 'SHIPMENT_PROOF'},
          )).thenAnswer((_) async => {
            'data': {'id': 'proof-1'}
          });

      final uploadRes = await repository.uploadShipmentProof('path/to/file.jpg');
      expect(uploadRes.isRight(), isTrue);
      expect(uploadRes.getOrElse(() => ''), equals('proof-1'));
    });
  });
}
