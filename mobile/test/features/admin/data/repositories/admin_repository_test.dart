import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/features/admin/data/repositories/admin_repository_impl.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApiService;
  late AdminRepositoryImpl repository;

  setUp(() {
    mockApiService = MockApiService();
    repository = AdminRepositoryImpl(apiService: mockApiService);
  });

  group('AdminRepositoryImpl Unit Tests', () {
    test('getMetrics parses data correctly on success', () async {
      when(() => mockApiService.get(any()))
          .thenAnswer((_) async => {'data': {'gmv': 1000000}});

      final result = await repository.getMetrics();
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('should be right'), (data) {
        expect(data['gmv'], equals(1000000));
      });
    });

    test('getMetrics maps 403 Forbidden to specific message', () async {
      when(() => mockApiService.get(any())).thenThrow(ApiException(
        statusCode: 403,
        message: 'Forbidden access',
      ));

      final result = await repository.getMetrics();
      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure.message, contains('Hanya akun Administrator'));
      }, (_) => fail('should be left'));
    });

    test('getDisputes handles status and pagination queries', () async {
      when(() => mockApiService.get(any()))
          .thenAnswer((_) async => {'data': [], 'pagination': {'total': 0}});

      final result = await repository.getDisputes(status: 'OPEN', page: 1, limit: 10);
      expect(result.isRight(), isTrue);
    });

    test('getDisputeDetail returns dispute detail map', () async {
      when(() => mockApiService.get('/admin/disputes/disp-1'))
          .thenAnswer((_) async => {'data': {'id': 'disp-1'}});

      final result = await repository.getDisputeDetail('disp-1');
      expect(result.isRight(), isTrue);
    });

    test('reviewDispute dispatches post review', () async {
      when(() => mockApiService.post('/admin/disputes/disp-1/review', {}))
          .thenAnswer((_) async => {'data': {'status': 'UNDER_REVIEW'}});

      final result = await repository.reviewDispute('disp-1');
      expect(result.isRight(), isTrue);
    });

    test('resolveDispute sends decision and note', () async {
      when(() => mockApiService.post('/admin/disputes/disp-1/resolve', {
            'decision': 'RELEASE_TO_SELLER',
            'note': 'Putusan sah',
          })).thenAnswer((_) async => {'data': {'status': 'RESOLVED_SELLER'}});

      final result = await repository.resolveDispute(
        'disp-1',
        decision: 'RELEASE_TO_SELLER',
        note: 'Putusan sah',
      );
      expect(result.isRight(), isTrue);
    });

    test('getKycSubmissions, approveKyc, and rejectKyc execute correctly', () async {
      when(() => mockApiService.get(any()))
          .thenAnswer((_) async => {'data': []});
      when(() => mockApiService.get('/admin/kyc/kyc-1'))
          .thenAnswer((_) async => {'data': {'id': 'kyc-1'}});
      when(() => mockApiService.post('/admin/kyc/kyc-1/approve', {}))
          .thenAnswer((_) async => {'data': {'status': 'APPROVED'}});
      when(() => mockApiService.post('/admin/kyc/kyc-1/reject', {'reason': 'Blur'}))
          .thenAnswer((_) async => {'data': {'status': 'REJECTED'}});

      final list = await repository.getKycSubmissions(status: 'PENDING');
      final detail = await repository.getKycDetail('kyc-1');
      final approve = await repository.approveKyc('kyc-1');
      final reject = await repository.rejectKyc('kyc-1', reason: 'Blur');

      expect(list.isRight(), isTrue);
      expect(detail.isRight(), isTrue);
      expect(approve.isRight(), isTrue);
      expect(reject.isRight(), isTrue);
    });

    test('getUsers, banUser, unbanUser execute correctly', () async {
      when(() => mockApiService.get(any()))
          .thenAnswer((_) async => {'data': []});
      when(() => mockApiService.post('/admin/users/u-1/ban', {'reason': 'Spam'}))
          .thenAnswer((_) async => {'data': {'isActive': false}});
      when(() => mockApiService.post('/admin/users/u-1/unban', {}))
          .thenAnswer((_) async => {'data': {'isActive': true}});

      final users = await repository.getUsers(search: 'budi');
      final ban = await repository.banUser('u-1', reason: 'Spam');
      final unban = await repository.unbanUser('u-1');

      expect(users.isRight(), isTrue);
      expect(ban.isRight(), isTrue);
      expect(unban.isRight(), isTrue);
    });

    test('getSettings, updateSetting, and getAuditLogs execute correctly', () async {
      when(() => mockApiService.get('/admin/settings'))
          .thenAnswer((_) async => {'data': {'fee_percent': '2.0'}});
      when(() => mockApiService.put('/admin/settings', {'key': 'fee_percent', 'value': '2.5'}))
          .thenAnswer((_) async => {'data': {'fee_percent': '2.5'}});
      when(() => mockApiService.get(any(that: startsWith('/admin/audit-logs'))))
          .thenAnswer((_) async => {'data': []});

      final settings = await repository.getSettings();
      final update = await repository.updateSetting('fee_percent', '2.5');
      final audit = await repository.getAuditLogs();

      expect(settings.isRight(), isTrue);
      expect(update.isRight(), isTrue);
      expect(audit.isRight(), isTrue);
    });

    test('getWithdrawals, approveWithdrawal, rejectWithdrawal execute correctly', () async {
      when(() => mockApiService.get(any()))
          .thenAnswer((_) async => {'data': {'withdrawals': []}});
      when(() => mockApiService.post('/admin/withdrawals/w-1/approve', {}))
          .thenAnswer((_) async => {'data': {'status': 'PROCESSING'}});
      when(() => mockApiService.post('/admin/withdrawals/w-1/reject', {'reason': 'Salah bank'}))
          .thenAnswer((_) async => {'data': {'status': 'REJECTED'}});

      final wList = await repository.getWithdrawals();
      final wApprove = await repository.approveWithdrawal('w-1');
      final wReject = await repository.rejectWithdrawal('w-1', reason: 'Salah bank');

      expect(wList.isRight(), isTrue);
      expect(wApprove.isRight(), isTrue);
      expect(wReject.isRight(), isTrue);
    });
  });
}
