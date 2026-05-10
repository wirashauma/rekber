import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/home/presentation/pages/main_wrapper.dart';
import '../../features/chat/presentation/pages/ai_assistant_screen.dart';

import '../../features/home/presentation/pages/notification_page.dart';
import '../../features/transaction/presentation/pages/transaction_detail_page.dart';
import '../../features/chat/presentation/pages/chat_room_page.dart';
import '../../features/wallet/presentation/pages/detail_pembayaran_screen.dart';
import '../../features/transaction/presentation/pages/buat_room_screen.dart';

/// REKBER App Router — GoRouter configuration
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    debugLogDiagnostics: true,
    routes: [
      // ── Auth Routes ──
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),

      // ── Main App Routes ──
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const MainWrapper(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationPage(),
      ),

      // ── Quick Action Routes ──
      GoRoute(
        path: '/topup',
        name: 'topup',
        builder: (context, state) => const TopUpScreen(),
      ),
      GoRoute(
        path: '/input-kode',
        name: 'input-kode',
        builder: (context, state) => const InputKodeScreen(),
      ),
      GoRoute(
        path: '/kalkulator',
        name: 'kalkulator',
        builder: (context, state) => const KalkulatorScreen(),
      ),
      GoRoute(
        path: '/tarik-dana',
        name: 'tarik-dana',
        builder: (context, state) => const TarikDanaScreen(),
      ),
      GoRoute(
        path: '/riwayat',
        name: 'riwayat',
        builder: (context, state) => const RiwayatScreen(),
      ),
      GoRoute(
        path: '/bantuan',
        name: 'bantuan',
        builder: (context, state) => const HelpCenterScreen(),
      ),
      GoRoute(
        path: '/buat-room',
        name: 'buat-room',
        builder: (context, state) => const BuatRoomScreen(),
      ),

      // ── Transaction Routes ──
      GoRoute(
        path: '/transaction/:id',
        name: 'transaction-detail',
        builder: (context, state) => const TransactionDetailPage(),
      ),

      // ── Chat Routes ──
      GoRoute(
        path: '/chat/:transactionId',
        name: 'chat-room-detail',
        builder: (context, state) => const ChatRoomPage(),
      ),
      GoRoute(
        path: '/chat-room',
        name: 'chat-room',
        builder: (context, state) => const ChatRoomPage(),
      ),
      GoRoute(
        path: '/ai-assistant',
        name: 'ai-assistant',
        builder: (context, state) => const AiAssistantScreen(),
      ),

      // ── Settings Sub-Screens ──
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/kyc',
        name: 'kyc',
        builder: (context, state) => const KycScreen(),
      ),
      GoRoute(
        path: '/help-center',
        name: 'help-center',
        builder: (context, state) => const HelpCenterScreen(),
      ),
      GoRoute(
        path: '/security',
        name: 'security',
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/legal',
        name: 'legal',
        builder: (context, state) => const LegalScreen(),
      ),
    ],

    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Halaman tidak ditemukan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              child: const Text('Kembali ke Beranda'),
            ),
          ],
        ),
      ),
    ),
  );
}
