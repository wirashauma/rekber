import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/rekber_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth;

/// Home Page — Role-switchable dashboard (Buyer ↔ Seller)
/// Follows Kupa-style home layout with delivery card, featured section, and grid
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _currentNavIndex = 0;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, auth.AuthState>(
      builder: (context, state) {
        if (state is! auth.AuthAuthenticated) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = state.user;
        final isBuyerView = state.activeRole == 'buyer';

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── App Bar ──
                SliverToBoxAdapter(
                  child: _buildHeader(user.fullName, isBuyerView),
                ),

                // ── Role Switcher ──
                SliverToBoxAdapter(
                  child: _buildRoleSwitcher(isBuyerView),
                ),

                // ── Content based on role ──
                if (isBuyerView) ..._buildBuyerContent()
                else ..._buildSellerContent(),

                // Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.xxxl + 20),
                ),
              ],
            ),
          ),

          // ── Bottom Navigation ──
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildHeader(String name, bool isBuyerView) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.xl,
        AppDimensions.base,
        AppDimensions.xl,
        AppDimensions.base,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $name 👋',
                  style: AppTextStyles.h4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isBuyerView ? 'Mode Pembeli' : 'Mode Penjual',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Notification bell
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.notifications_outlined,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSwitcher(bool isBuyerView) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.xl,
        vertical: AppDimensions.sm,
      ),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _switchRole('buyer'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isBuyerView ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    boxShadow: isBuyerView
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 18,
                          color: isBuyerView ? Colors.white : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Pembeli',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isBuyerView
                                ? Colors.white
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _switchRole('seller'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: !isBuyerView ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    boxShadow: !isBuyerView
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 18,
                          color: !isBuyerView ? Colors.white : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Penjual',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: !isBuyerView
                                ? Colors.white
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BUYER CONTENT ──
  List<Widget> _buildBuyerContent() {
    return [
      // Quick action: Create Transaction
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.xl),
          child: _buildQuickActionCard(),
        ),
      ),

      // Active transactions header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Transaksi Aktif', style: AppTextStyles.h4),
              TextButton(
                onPressed: () {},
                child: const Text('Lihat Semua'),
              ),
            ],
          ),
        ),
      ),

      // Transaction list (mock data)
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.xl,
              vertical: AppDimensions.xs,
            ),
            child: _buildTransactionCard(index),
          ),
          childCount: 3,
        ),
      ),
    ];
  }

  Widget _buildQuickActionCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaksi Aman',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Dana dijaga hingga barang diterima',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.base),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Navigate to create transaction
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'Buat Transaksi Baru',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(int index) {
    // Mock data
    final mockData = [
      {
        'txCode': 'RKB-20260508-001234',
        'sellerName': 'Toko Elektronik Jakarta',
        'amount': 2500000,
        'status': 'escrow',
        'description': 'iPhone 15 Case Premium',
      },
      {
        'txCode': 'RKB-20260507-001233',
        'sellerName': 'Fashion Store ID',
        'amount': 450000,
        'status': 'shipped',
        'description': 'Kemeja Batik Pria',
      },
      {
        'txCode': 'RKB-20260506-001232',
        'sellerName': 'Gadget World',
        'amount': 1200000,
        'status': 'awaiting_payment',
        'description': 'TWS Earbuds Pro',
      },
    ];

    final data = mockData[index];

    return RekberCard(
      statusColor: AppColors.getStatusColor(data['status'] as String),
      onTap: () {
        // TODO: Navigate to transaction detail
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                data['txCode'] as String,
                style: AppTextStyles.labelSmall.copyWith(
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
              StatusBadge(
                status: data['status'] as String,
                isCompact: true,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            data['description'] as String,
            style: AppTextStyles.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            data['sellerName'] as String,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            CurrencyFormatter.format(data['amount'] as int),
            style: AppTextStyles.currencySmall,
          ),
        ],
      ),
    );
  }

  // ── SELLER CONTENT ──
  List<Widget> _buildSellerContent() {
    return [
      // Wallet Summary
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.xl),
          child: _buildWalletSummary(),
        ),
      ),

      // Stats row
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
          child: _buildStatsRow(),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.lg)),

      // Active orders header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pesanan Masuk', style: AppTextStyles.h4),
              TextButton(
                onPressed: () {},
                child: const Text('Lihat Semua'),
              ),
            ],
          ),
        ),
      ),

      // Order list (mock)
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.xl,
              vertical: AppDimensions.xs,
            ),
            child: _buildSellerOrderCard(index),
          ),
          childCount: 2,
        ),
      ),
    ];
  }

  Widget _buildWalletSummary() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo Tersedia',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Rp3.750.000',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppDimensions.base),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dana Escrow',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Rp1.500.000',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Navigate to withdrawal
                  },
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  label: const Text('Tarik Dana'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatItem('Pesanan Aktif', '5', Icons.inventory_2_outlined, AppColors.info)),
        const SizedBox(width: AppDimensions.sm),
        Expanded(child: _buildStatItem('Selesai', '28', Icons.check_circle_outline, AppColors.success)),
        const SizedBox(width: AppDimensions.sm),
        Expanded(child: _buildStatItem('Sengketa', '1', Icons.warning_amber_rounded, AppColors.warning)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.h3.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSellerOrderCard(int index) {
    final orders = [
      {
        'buyerName': 'Ahmad Rizki',
        'amount': 850000,
        'status': 'escrow',
        'description': 'Keyboard Mechanical RGB',
        'time': '2 jam lalu',
      },
      {
        'buyerName': 'Siti Nurhaliza',
        'amount': 320000,
        'status': 'processed',
        'description': 'Tas Laptop 15 inch',
        'time': '5 jam lalu',
      },
    ];
    final order = orders[index];

    return RekberCard(
      statusColor: AppColors.getStatusColor(order['status'] as String),
      onTap: () {},
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Center(
              child: Text(
                (order['buyerName'] as String)[0],
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order['description'] as String, style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(
                  '${order['buyerName']} • ${order['time']}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(order['amount'] as int),
                style: AppTextStyles.currencySmall.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 4),
              StatusBadge(status: order['status'] as String, isCompact: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: AppDimensions.bottomNavHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
              _buildNavItem(1, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Transaksi'),
              _buildNavItem(2, Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Chat'),
              _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData icon, String label) {
    final isActive = _currentNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 48 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textTertiary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _switchRole(String role) {
    context.read<AuthBloc>().add(AuthRoleSwitched(newRole: role));
  }
}
