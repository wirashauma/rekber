import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/widgets/rekber_balance_card.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../transaction/data/models/transaction_model.dart';
import '../../../../injection_container.dart';
import '../../../../core/services/api_service.dart';

import '../widgets/auto_scroll_banner.dart';

/// Home Dashboard — Neo-Brutalism (Saweria Style)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = true;
  List<TransactionModel> _transactions = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    context.read<AuthBloc>().add(AuthCheckRequested());
    await _fetchTransactions();
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      final response = await sl<ApiService>().get('/transactions');
      if (response != null && response['data'] != null) {
        final List<dynamic> data = response['data'];
        setState(() {
          _transactions = data.map((e) => TransactionModel.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final balance = user is UserModel ? user.balance : 0.0;
        
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: AppColors.black,
              backgroundColor: AppColors.white,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                // ── Custom Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Halo Gan! 👋', style: AppTextStyles.h2),
                            Text(
                              user?.fullName ?? 'Guest',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                        BrutalistBounce(
                          onTap: () => context.push('/notifications'),
                          child: Image.asset(
                            'assets/images/notify.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Massive Balance Card ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: isLoading
                        ? const BrutalSkeleton(
                            width: double.infinity,
                            height: 200,
                            borderRadius: 12.0,
                          )
                        : RekberBalanceCard(
                            principalBalance: balance,
                            activeBalance: balance,
                            guaranteeBalance: 0.0,
                          ),
                  ),
                ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ── Quick Actions ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // Row 1
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedBrutalButton(
                            icon: Icons.add_box_rounded,
                            label: 'Top Up',
                            onTap: () => context.push('/topup'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedBrutalButton(
                            icon: Icons.vpn_key_rounded,
                            label: 'Input Kode',
                            onTap: () => context.push('/input-kode'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedBrutalButton(
                            icon: Icons.calculate_rounded,
                            label: 'Kalkulator',
                            onTap: () => context.push('/kalkulator'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Row 2
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedBrutalButton(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Tarik Dana',
                            onTap: () => context.push('/tarik-dana'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedBrutalButton(
                            icon: Icons.history_rounded,
                            label: 'Riwayat',
                            onTap: () => context.push('/riwayat'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedBrutalButton(
                            icon: Icons.help_outline_rounded,
                            label: 'Bantuan',
                            onTap: () => context.push('/bantuan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),

            // ── Auto Scrolling Banners ──
            const SliverToBoxAdapter(
              child: AutoScrollBanner(),
            ),


            const SliverToBoxAdapter(child: SizedBox(height: 40)),

            // ── Recent Transactions Header ──
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TRANSAKSI AKTIF', style: AppTextStyles.h3),
                    Icon(Icons.arrow_forward_rounded, size: 28),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (isLoading) {
                      return const BrutalSkeletonCard();
                    }

                    if (_transactions.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border.all(color: AppColors.black, width: 2.5),
                          boxShadow: const [
                            BoxShadow(color: AppColors.black, offset: Offset(4, 4)),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Belum ada transaksi aktif.',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }

                    final trx = _transactions[index];
                    
                    final lightColors = [AppColors.white, AppColors.paleYellow, AppColors.lightBlue];
                    final bgColor = lightColors[index % lightColors.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: BrutalistBounce(
                        onTap: () => context.push('/chat/${trx.id}'),
                        child: BrutalistCard(
                          backgroundColor: bgColor,
                          padding: const EdgeInsets.all(16),
                          shadowOffset: const Offset(4, 4),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppColors.getStatusColor(trx.status),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.black, width: 3),
                                ),
                                child: const Icon(Icons.receipt_long_rounded, color: AppColors.black, size: 32),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trx.description ?? 'No Description',
                                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w900),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tujuan: @${trx.sellerName ?? 'Unknown'} • ${_formatDate(trx.createdAt)}',
                                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (trx.status == 'escrow' || trx.status == 'paid') ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.black,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '⏳ Garansi Aktif',
                                          style: TextStyle(
                                            color: AppColors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      CurrencyFormatter.format(trx.amount),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.black,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    _buildStatusIndicator(trx.status),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: isLoading ? 3 : (_transactions.isEmpty ? 1 : _transactions.length),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    ),
    );
  },
);
}

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

  Widget _buildStatusIndicator(String status) {
    String text;
    Color bgColor;
    const Color textColor = AppColors.black;

    switch (status) {
      case 'awaiting_payment':
        text = 'BELUM BAYAR';
        bgColor = const Color(0xFFFFB6C1); // Pink
        break;
      case 'escrow':
        text = 'DANA AMAN';
        bgColor = AppColors.accent; // Neon Green
        break;
      case 'completed':
        text = 'SELESAI';
        bgColor = AppColors.white;
        break;
      default:
        text = status.toUpperCase();
        bgColor = AppColors.white;
    }

    return BrutalistBadge(
      text: text,
      backgroundColor: bgColor,
      textColor: textColor,
    );
  }

  // Helper was replaced by direct AnimatedBrutalButton usage in the grid
}

