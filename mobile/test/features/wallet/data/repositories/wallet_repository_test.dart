import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/features/wallet/data/repositories/wallet_repository_impl.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApiService;
  late WalletRepositoryImpl repository;

  setUp(() {
    mockApiService = MockApiService();
    repository = WalletRepositoryImpl(apiService: mockApiService);
  });

  group('WalletRepository - Parsing Backend JSON Fixtures', () {
    test('getWalletSummary parses balance and heldBalance', () async {
      final fixture = {
        'success': true,
        'data': {
          'balance': 1500000,
          'heldBalance': 300000,
        }
      };

      when(() => mockApiService.get('/wallet'))
          .thenAnswer((_) async => fixture);

      final result = await repository.getWalletSummary();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Harus sukses'),
        (summary) {
          expect(summary.balance, 1500000);
          expect(summary.heldBalance, 300000);
          expect(summary.totalBalance, 1800000);
        },
      );
    });

    test('createTopUp parses PaymentIntent accurately', () async {
      final fixture = {
        'success': true,
        'data': {
          'id': 'intent-123',
          'provider': 'XENDIT',
          'referenceId': 'TOP-888',
          'amount': 100000,
          'method': 'QRIS',
          'status': 'PENDING',
          'qrString': '00020101021226500016ID.CO.XENDIT',
          'createdAt': '2026-03-25T10:00:00Z',
        }
      };

      when(() => mockApiService.post('/wallet/topups', {'amount': 100000, 'method': 'QRIS'}))
          .thenAnswer((_) async => fixture);

      final result = await repository.createTopUp(amount: 100000, method: 'QRIS');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Harus sukses'),
        (intent) {
          expect(intent.id, 'intent-123');
          expect(intent.amount, 100000);
          expect(intent.method, 'QRIS');
          expect(intent.isPending, isTrue);
          expect(intent.qrString, isNotNull);
        },
      );
    });

    test('getBankAccounts parses list of masked accounts', () async {
      final fixture = {
        'success': true,
        'data': [
          {
            'id': 'acc-1',
            'bankCode': 'BCA',
            'accountLast4': '9876',
            'accountName': 'Budi Santoso',
            'isDefault': true,
            'createdAt': '2026-03-25T10:00:00Z',
          }
        ]
      };

      when(() => mockApiService.get('/bank-accounts'))
          .thenAnswer((_) async => fixture);

      final result = await repository.getBankAccounts();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Harus sukses'),
        (list) {
          expect(list.length, 1);
          expect(list.first.maskedNumber, '•••• 9876');
          expect(list.first.bankCode, 'BCA');
        },
      );
    });

    test('getLedgerHistory parses ledger mutasi entries', () async {
      final fixture = {
        'success': true,
        'data': {
          'entries': [
            {
              'id': 'led-1',
              'amount': 50000,
              'type': 'CREDIT',
              'balanceAfter': 500000,
              'referenceType': 'TOP_UP',
              'referenceId': 'top-1',
              'createdAt': '2026-03-25T10:00:00Z',
            }
          ]
        }
      };

      when(() => mockApiService.get(any()))
          .thenAnswer((_) async => fixture);

      final result = await repository.getLedgerHistory();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Harus sukses'),
        (list) {
          expect(list.length, 1);
          expect(list.first.isCredit, isTrue);
          expect(list.first.amount, 50000);
          expect(list.first.balanceAfter, 500000);
        },
      );
    });

    test('getTopUpStatus parses status correctly', () async {
      when(() => mockApiService.get('/wallet/topups/top-1')).thenAnswer((_) async => {
        'success': true,
        'data': {
          'id': 'top-1',
          'provider': 'XENDIT',
          'referenceId': 'REF-1',
          'amount': 50000,
          'method': 'QRIS',
          'status': 'PAID',
          'createdAt': '2026-03-25T10:00:00Z',
        }
      });
      final res = await repository.getTopUpStatus('top-1');
      expect(res.isRight(), isTrue);
    });

    test('createBankAccount, deleteBankAccount execute correctly', () async {
      when(() => mockApiService.post('/bank-accounts', any())).thenAnswer((_) async => {
        'success': true,
        'data': {
          'id': 'acc-2',
          'bankCode': 'BRI',
          'accountLast4': '1122',
          'accountName': 'Budi',
          'isDefault': false,
          'createdAt': '2026-03-25T10:00:00Z',
        }
      });
      when(() => mockApiService.delete('/bank-accounts/acc-2')).thenAnswer((_) async => {
        'success': true,
      });

      final createRes = await repository.createBankAccount(
        bankCode: 'BRI',
        accountNumber: '123456789',
        accountName: 'Budi',
      );
      expect(createRes.isRight(), isTrue);

      final delRes = await repository.deleteBankAccount('acc-2');
      expect(delRes.isRight(), isTrue);
    });

    test('requestWithdrawal, getWithdrawals, cancelWithdrawal execute correctly', () async {
      when(() => mockApiService.post(
            '/wallet/withdrawals',
            any(),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'success': true,
            'data': {
              'id': 'w-1',
              'bankAccountId': 'acc-1',
              'amount': 100000,
              'fee': 2500,
              'status': 'PENDING_REVIEW',
              'createdAt': '2026-03-25T10:00:00Z',
            }
          });
      when(() => mockApiService.get('/wallet/withdrawals')).thenAnswer((_) async => {
        'success': true,
        'data': []
      });
      when(() => mockApiService.post('/wallet/withdrawals/w-1/cancel', {})).thenAnswer((_) async => {
        'success': true,
      });

      final req = await repository.requestWithdrawal(
        bankAccountId: 'acc-1',
        amount: 100000,
        idempotencyKey: 'idemp-1',
      );
      expect(req.isRight(), isTrue);

      final list = await repository.getWithdrawals();
      expect(list.isRight(), isTrue);

      final cancel = await repository.cancelWithdrawal('w-1');
      expect(cancel.isRight(), isTrue);
    });

    test('handles ApiException and generic errors gracefully', () async {
      when(() => mockApiService.get('/wallet'))
          .thenThrow(ApiException(statusCode: 500, message: 'Internal Server Error'));
      when(() => mockApiService.post('/wallet/topups', any()))
          .thenThrow(Exception('Unknown network error'));

      final sumRes = await repository.getWalletSummary();
      expect(sumRes.isLeft(), isTrue);

      final topUpRes = await repository.createTopUp(amount: 10000, method: 'QRIS');
      expect(topUpRes.isLeft(), isTrue);
    });
  });
}
