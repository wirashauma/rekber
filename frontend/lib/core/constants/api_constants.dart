/// REKBER API & Supabase Constants
class ApiConstants {
  ApiConstants._();

  // ── Supabase (replace with your project values) ──
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // ── Edge Function Endpoints ──
  static const String createTransaction = '/functions/v1/create-transaction';
  static const String processPayment = '/functions/v1/process-payment';
  static const String updateTransactionStatus = '/functions/v1/update-transaction-status';
  static const String processWithdrawal = '/functions/v1/process-withdrawal';
  static const String webhookPayment = '/functions/v1/webhook-payment';

  // ── Storage Buckets ──
  static const String kycBucket = 'kyc-documents';
  static const String proofBucket = 'transaction-proofs';
  static const String productBucket = 'product-images';
  static const String chatBucket = 'chat-attachments';
  static const String avatarBucket = 'avatars';

  // ── Platform Fee ──
  static const double platformFeePercent = 0.025; // 2.5%

  // ── Timeouts ──
  static const Duration paymentTimeout = Duration(hours: 24);
  static const Duration requestTimeout = Duration(seconds: 30);
}
