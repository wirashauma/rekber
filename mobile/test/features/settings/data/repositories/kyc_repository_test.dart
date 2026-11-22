import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rekber/core/services/api_service.dart';
import 'package:rekber/features/settings/data/repositories/kyc_repository_impl.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockApiService mockApiService;
  late KycRepositoryImpl repository;

  setUp(() {
    mockApiService = MockApiService();
    repository = KycRepositoryImpl(apiService: mockApiService);
  });

  group('KycRepositoryImpl Unit Tests', () {
    test('getMyKyc returns data map on success', () async {
      when(() => mockApiService.get('/kyc/me')).thenAnswer((_) async => {
            'data': {'kycStatus': 'NONE'}
          });

      final result = await repository.getMyKyc();
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('should be right'), (data) {
        expect(data['kycStatus'], equals('NONE'));
      });
    });

    test('uploadKycFile posts multipart and returns fileId', () async {
      when(() => mockApiService.postMultipart(
            '/files',
            fieldName: 'file',
            filePath: any(named: 'filePath'),
            fields: {'purpose': 'KYC_ID'},
          )).thenAnswer((_) async => {
            'data': {'id': 'file-kyc-123'}
          });

      final result = await repository.uploadKycFile(File('ktp.png'), 'KYC_ID');
      expect(result.isRight(), isTrue);
      result.fold((_) => fail('should be right'), (id) {
        expect(id, equals('file-kyc-123'));
      });
    });

    test('submitKyc posts user verification payload', () async {
      when(() => mockApiService.post('/kyc', {
            'fullName': 'Budi Santoso',
            'nik': '3201123456780001',
            'idFileId': 'file-1',
            'selfieFileId': 'file-2',
          })).thenAnswer((_) async => {
            'data': {'status': 'PENDING'}
          });

      final result = await repository.submitKyc(
        fullName: 'Budi Santoso',
        nik: '3201123456780001',
        idFileId: 'file-1',
        selfieFileId: 'file-2',
      );

      expect(result.isRight(), isTrue);
      result.fold((_) => fail('should be right'), (data) {
        expect(data['status'], equals('PENDING'));
      });
    });

    test('handles ApiException and generic errors gracefully', () async {
      when(() => mockApiService.get('/kyc/me'))
          .thenThrow(ApiException(statusCode: 404, message: 'Belum mengajukan KYC'));
      when(() => mockApiService.post('/kyc', any()))
          .thenThrow(Exception('Koneksi terputus'));

      final getRes = await repository.getMyKyc();
      expect(getRes.isLeft(), isTrue);

      final submitRes = await repository.submitKyc(
        fullName: 'Budi',
        nik: '1234567890123456',
        idFileId: 'f1',
        selfieFileId: 'f2',
      );
      expect(submitRes.isLeft(), isTrue);
    });
  });
}
