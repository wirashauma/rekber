import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/errors/failures.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/features/dispute/data/repositories/dispute_repository_impl.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApiService;
  late DisputeRepositoryImpl repository;

  setUp(() {
    mockApiService = MockApiService();
    repository = DisputeRepositoryImpl(apiService: mockApiService);
  });

  group('DisputeRepositoryImpl Unit Tests', () {
    test('openDispute posts dispute data and returns DisputeEntity', () async {
      when(() => mockApiService.post('/transactions/tx-1/dispute', {
            'reason': 'NOT_RECEIVED',
            'description': 'Barang tidak kunjung sampai.',
          })).thenAnswer((_) async => {
            'data': {
              'id': 'disp-1',
              'transactionId': 'tx-1',
              'reason': 'NOT_RECEIVED',
              'description': 'Barang tidak kunjung sampai.',
              'status': 'OPEN',
              'createdAt': '2026-05-10T10:00:00.000Z',
            }
          });

      final result = await repository.openDispute(
        transactionId: 'tx-1',
        reason: 'NOT_RECEIVED',
        description: 'Barang tidak kunjung sampai.',
      );

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('should be right'), (entity) {
        expect(entity.id, equals('disp-1'));
        expect(entity.status, equals('OPEN'));
      });
    });

    test('openDispute maps 409 conflict to ConflictFailure', () async {
      when(() => mockApiService.post(any(), any())).thenThrow(ApiException(
        statusCode: 409,
        message: 'Sengketa sudah diajukan sebelumnya.',
      ));

      final result = await repository.openDispute(
        transactionId: 'tx-1',
        reason: 'NOT_RECEIVED',
        description: 'Barang tidak kunjung sampai.',
      );

      expect(result.isLeft(), isTrue);
      result.fold((failure) {
        expect(failure.message, contains('sudah diajukan'));
      }, (_) => fail('should be left'));
    });

    test('getDisputeById and getDisputeByTransactionId return DisputeEntity', () async {
      final tJson = {
        'data': {
          'id': 'disp-1',
          'transactionId': 'tx-1',
          'reason': 'DEFECTIVE',
          'description': 'Barang rusak saat tiba.',
          'status': 'UNDER_REVIEW',
          'createdAt': '2026-05-10T10:00:00.000Z',
        }
      };

      when(() => mockApiService.get('/disputes/disp-1')).thenAnswer((_) async => tJson);
      when(() => mockApiService.get('/transactions/tx-1/dispute')).thenAnswer((_) async => tJson);

      final byId = await repository.getDisputeById('disp-1');
      final byTx = await repository.getDisputeByTransactionId('tx-1');

      expect(byId.isRight(), isTrue);
      expect(byTx.isRight(), isTrue);
    });

    test('submitEvidence posts note and fileIds', () async {
      when(() => mockApiService.post('/disputes/disp-1/evidence', {
            'note': 'Ini bukti unboxing',
            'fileIds': ['file-1'],
          })).thenAnswer((_) async => {
            'data': {'id': 'ev-1', 'note': 'Ini bukti unboxing'}
          });

      final result = await repository.submitEvidence(
        disputeId: 'disp-1',
        note: 'Ini bukti unboxing',
        fileIds: ['file-1'],
      );

      expect(result.isRight(), isTrue);
    });

    test('uploadDisputeEvidence posts multipart file', () async {
      when(() => mockApiService.postMultipart(
            '/files',
            fieldName: 'file',
            filePath: any(named: 'filePath'),
            fields: {'purpose': 'DISPUTE_EVIDENCE'},
          )).thenAnswer((_) async => {
            'data': {'id': 'file-asset-123'}
          });

      final result = await repository.uploadDisputeEvidence('evidence.png');
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('should be right'), (id) {
        expect(id, equals('file-asset-123'));
      });
    });

    test('getFileUrl returns signed url and handles errors', () async {
      when(() => mockApiService.get('/files/file-1/url')).thenAnswer((_) async => {
        'data': {'url': 'https://signed.url/1'}
      });
      when(() => mockApiService.get('/files/file-err/url'))
          .thenThrow(ApiException(statusCode: 404, message: 'File not found'));

      final successRes = await repository.getFileUrl('file-1');
      expect(successRes.isRight(), isTrue);
      expect(successRes.getOrElse(() => ''), equals('https://signed.url/1'));

      final errRes = await repository.getFileUrl('file-err');
      expect(errRes.isLeft(), isTrue);
    });

    test('openDispute handles 409 conflict and generic exceptions', () async {
      when(() => mockApiService.post('/transactions/tx-1/dispute', any()))
          .thenThrow(ApiException(statusCode: 409, message: 'Dispute already open'));
      when(() => mockApiService.post('/transactions/tx-2/dispute', any()))
          .thenThrow(Exception('Timeout'));

      final confRes = await repository.openDispute(
        transactionId: 'tx-1',
        reason: 'OTHER',
        description: 'deskripsi panjang lebih dari 20 huruf',
      );
      expect(confRes.isLeft(), isTrue);
      expect(confRes.fold((l) => (l as ServerFailure).statusCode, (_) => null), equals(409));

      final genRes = await repository.openDispute(
        transactionId: 'tx-2',
        reason: 'OTHER',
        description: 'deskripsi panjang lebih dari 20 huruf',
      );
      expect(genRes.isLeft(), isTrue);
    });
  });
}
