import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rekber/core/services/api_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E Integration Test - Escrow Flow', () {
    late ApiService apiServiceA;
    late ApiService apiServiceB;
    
    final buyerEmail = 'buyer_${DateTime.now().millisecondsSinceEpoch}@example.com';
    final sellerEmail = 'seller_${DateTime.now().millisecondsSinceEpoch}@example.com';
    const password = 'password123';
    
    String buyerId = '';
    String sellerId = '';
    String transactionId = '';

    setUpAll(() {
      apiServiceA = ApiService(); // Represents User A (Buyer)
      apiServiceB = ApiService(); // Represents User B (Seller)
    });

    testWidgets('Step 1: User A (Buyer) registers and logs in', (tester) async {
      // Register
      await apiServiceA.post('/auth/register', {
        'email': buyerEmail,
        'password': password,
        'name': 'Buyer User A',
      });
      
      // Login
      final loginResponse = await apiServiceA.post('/auth/login', {
        'email': buyerEmail,
        'password': password,
      });
      
      expect(loginResponse['data']['token'], isNotNull);
      await apiServiceA.saveToken(loginResponse['data']['token']);
      buyerId = loginResponse['data']['user']['id'].toString();
    });

    testWidgets('Step 2: User B (Seller) registers and logs in', (tester) async {
      // Register
      await apiServiceB.post('/auth/register', {
        'email': sellerEmail,
        'password': password,
        'name': 'Seller User B',
      });
      
      // Login
      final loginResponse = await apiServiceB.post('/auth/login', {
        'email': sellerEmail,
        'password': password,
      });
      
      expect(loginResponse['data']['token'], isNotNull);
      await apiServiceB.saveToken(loginResponse['data']['token']);
      sellerId = loginResponse['data']['user']['id'].toString();
    });

    testWidgets('Step 3: User A creates a new Escrow Transaction', (tester) async {
      final transactionResponse = await apiServiceA.post('/transactions', {
        'sellerId': sellerId,
        'amount': 500000,
        'itemDescription': 'Test Item',
      });
      
      expect(transactionResponse['data']['id'], isNotNull);
      expect(transactionResponse['data']['status'], 'PENDING');
      transactionId = transactionResponse['data']['id'].toString();
    });

    testWidgets('Step 4: User A fetches the transaction list to verify PENDING status', (tester) async {
      // Depending on the backend routes, it might be GET /transactions or GET /transactions/:id
      // For now, we will just fetch the specific transaction we created
      final response = await apiServiceA.get('/transactions/$transactionId');
      
      expect(response['data']['id'].toString(), transactionId);
      expect(response['data']['status'], 'PENDING');
      expect(response['data']['amount'], 500000);
      expect(response['data']['itemDescription'], 'Test Item');
    });
  });
}
