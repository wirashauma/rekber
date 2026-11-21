import 'package:flutter_test/flutter_test.dart';
import 'package:rekber/core/services/api_service.dart';

void main() {
  test('Smoke test: Inisialisasi ApiService', () {
    final apiService = ApiService();
    expect(apiService, isNotNull);
    expect(ApiService.baseUrl, isNotEmpty);
  });
}
