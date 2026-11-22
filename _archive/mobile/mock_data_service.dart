import 'package:rekber/features/auth/domain/entities/user_entity.dart';

/// Mock Data Service — Robust dummy data for REKBER testing
class MockDataService {
  MockDataService._();

  static final UserEntity dummyUser = UserEntity(
    id: 'user-123',
    email: 'user@rekber.com',
    fullName: 'User Rekber',
    phone: '08123456789',
    avatarUrl: 'https://i.pravatar.cc/150?u=user',
    role: 'user',
    kycStatus: 'verified',
    isActive: true,
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
  );

  static const double dummyEscrowBalance = 2500000.0;
  static const double dummyAvailableBalance = 750000.0;

  static final List<Map<String, dynamic>> dummyTransactions = [
    {
      'id': 'TRX-001',
      'description': 'Beli Akun Valorant Immortal',
      'amount': 450000.0,
      'status': 'awaiting_payment',
      'counterparty': 'rizky_gaming',
      'date': '2 jam yang lalu',
    },
    {
      'id': 'TRX-002',
      'description': 'Jasa GB Rank Mobile Legends',
      'amount': 150000.0,
      'status': 'escrow',
      'counterparty': 'mlbb_pro_gb',
      'date': '5 jam yang lalu',
    },
    {
      'id': 'TRX-003',
      'description': 'Top Up Discord Nitro 1 Year',
      'amount': 800000.0,
      'status': 'escrow',
      'counterparty': 'nitro_cheap_store',
      'date': 'Yesterday',
    },
    {
      'id': 'TRX-004',
      'description': 'Design Logo Twitch Streamer',
      'amount': 1200000.0,
      'status': 'completed',
      'counterparty': 'art_by_nana',
      'date': '3 days ago',
    },
    {
      'id': 'TRX-005',
      'description': 'Voucher Steam Wallet \$50',
      'amount': 750000.0,
      'status': 'completed',
      'counterparty': 'steam_vouchers',
      'date': '1 week ago',
    },
  ];

  static final List<Map<String, dynamic>> dummyMessages = [
    {'sender': 'user_2', 'text': 'Halo gan, akun sudah siap dioper.', 'time': '10:00'},
    {'sender': 'user_1', 'text': 'Oke gan, dana sudah saya masukkan ke rekber.', 'time': '10:05'},
    {'sender': 'user_2', 'text': 'Siap, tunggu sebentar saya kirim datanya.', 'time': '10:07'},
    {'sender': 'user_2', 'text': 'Cek PM ya gan.', 'time': '10:10'},
  ];
}

