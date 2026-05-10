import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/services/mock_data_service.dart';
import '../../../../core/utils/currency_formatter.dart';

import '../widgets/auto_scroll_banner.dart';

/// Home Dashboard — Neo-Brutalism (Saweria Style)
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
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
                        Text(MockDataService.dummyUser.fullName, style: AppTextStyles.bodyMedium),
                      ],
                    ),
                    BrutalistBounce(
                      onTap: () => context.push('/notifications'),
                      child: const BrutalistCard(
                        borderRadius: 12,
                        padding: EdgeInsets.all(8),
                        shadowOffset: Offset(4, 4),
                        borderWidth: 3,
                        child: Icon(Icons.notifications_active_outlined, size: 24),
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
                    : BrutalistCard(
                        backgroundColor: AppColors.tealGreen,
                        padding: const EdgeInsets.all(24),
                        shadowOffset: const Offset(4, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SALDO REKBER',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              CurrencyFormatter.format(MockDataService.dummyEscrowBalance.toInt()),
                              style: AppTextStyles.currency.copyWith(
                                color: AppColors.white,
                                fontSize: 32,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.black, width: 3),
                              ),
                              child: Row(
                                children: [
                                  // --- Saldo Aktif ---
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Saldo Aktif',
                                          style: TextStyle(
                                            color: AppColors.black,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          CurrencyFormatter.format(MockDataService.dummyAvailableBalance.toInt()),
                                          style: const TextStyle(
                                            color: AppColors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // --- Divider Vertical ---
                                  Container(
                                    height: 30,
                                    width: 3,
                                    color: AppColors.black,
                                    margin: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  // --- Saldo Tertahan ---
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Masa Garansi',
                                          style: TextStyle(
                                            color: AppColors.black,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          CurrencyFormatter.format(
                                            (MockDataService.dummyEscrowBalance - MockDataService.dummyAvailableBalance).toInt(),
                                          ),
                                          style: const TextStyle(
                                            color: AppColors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

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

            // ── Transactions List ──
            SliverPadding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (isLoading) {
                      return const BrutalSkeletonCard();
                    }

                    final trx = MockDataService.dummyTransactions[index];
                    final lightColors = [AppColors.white, AppColors.paleYellow, AppColors.lightBlue];
                    final bgColor = lightColors[index % lightColors.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
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
                                color: AppColors.getStatusColor(trx['status']),
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
                                    trx['description'],
                                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w900),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tujuan: @${trx['counterparty'] ?? 'Tujuan belum diatur'} • ${trx['date']}',
                                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (trx['status'] == 'escrow') ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.black,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        '⏳ Garansi: 47 Jam',
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
                                    CurrencyFormatter.format(trx['amount'].toInt()),
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  _buildStatusIndicator(trx['status']),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: isLoading ? 3 : MockDataService.dummyTransactions.length,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
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

