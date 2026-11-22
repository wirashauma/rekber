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
import '../../../transaction/presentation/cubit/transaction_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_state.dart';
import '../../../wallet/presentation/cubit/wallet_cubit.dart';
import '../../../wallet/presentation/cubit/wallet_state.dart';
import '../../../transaction/domain/services/escrow_state_machine.dart';
import '../../../notification/presentation/cubit/notification_cubit.dart';
import '../../../notification/presentation/cubit/notification_state.dart';
import '../widgets/auto_scroll_banner.dart';

/// Home Dashboard — Neo-Brutalism
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    context.read<AuthBloc>().add(AuthCheckRequested());
    context.read<WalletCubit>().loadWalletData();
    context.read<TransactionCubit>().loadTransactions();
    context.read<NotificationCubit>().loadUnreadCount();
  }

  Future<void> _refreshData() async {
    context.read<AuthBloc>().add(AuthCheckRequested());
    context.read<WalletCubit>().loadWalletData();
    context.read<NotificationCubit>().loadUnreadCount();
    await context.read<TransactionCubit>().loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
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
                  child: BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, authState) {
                      final user = authState is AuthAuthenticated ? authState.user : null;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Halo Gan! 👋', style: AppTextStyles.h2),
                              Text(
                                user?.fullName ?? 'Pengguna Rekber',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ],
                          ),
                          BlocBuilder<NotificationCubit, NotificationState>(
                            builder: (context, notifState) {
                              final unreadCount = notifState is NotificationLoaded
                                  ? notifState.unreadCount
                                  : context.read<NotificationCubit>().unreadCount;

                              return BrutalistBounce(
                                onTap: () => context.push('/notifications'),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Image.asset(
                                      'assets/images/notify.png',
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.mustardYellow,
                                          border: Border.all(color: AppColors.black, width: 2),
                                        ),
                                        child: const Icon(Icons.notifications_rounded, color: AppColors.black),
                                      ),
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                          decoration: BoxDecoration(
                                            color: AppColors.error,
                                            border: Border.all(color: AppColors.black, width: 2),
                                            borderRadius: BorderRadius.circular(9),
                                          ),
                                          child: Text(
                                            unreadCount > 99 ? '99+' : '$unreadCount',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: AppColors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // ── Massive Balance Card ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: BlocBuilder<WalletCubit, WalletState>(
                    builder: (context, walletState) {
                      if (walletState is WalletLoading) {
                        return const BrutalSkeleton(
                          width: double.infinity,
                          height: 200,
                          borderRadius: 12.0,
                        );
                      }

                      int balance = 0;
                      int held = 0;

                      if (walletState is WalletLoaded) {
                        balance = walletState.summary.balance;
                        held = walletState.summary.heldBalance;
                      } else {
                        final authState = context.read<AuthBloc>().state;
                        if (authState is AuthAuthenticated && authState.user is UserModel) {
                          balance = (authState.user as UserModel).balance.toInt();
                        }
                      }

                      return InkWell(
                        onTap: () => context.push('/riwayat-mutasi'),
                        child: RekberBalanceCard(
                          principalBalance: balance.toDouble(),
                          activeBalance: balance.toDouble(),
                          guaranteeBalance: held.toDouble(),
                        ),
                      );
                    },
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
                              icon: Icons.receipt_long_rounded,
                              label: 'Mutasi',
                              onTap: () => context.push('/riwayat-mutasi'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 36)),

              // ── Auto Scrolling Banners ──
              const SliverToBoxAdapter(
                child: AutoScrollBanner(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 36)),

              // ── Transactions Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TRANSAKSI ANDA', style: AppTextStyles.h3),
                      GestureDetector(
                        onTap: () => context.push('/riwayat'),
                        child: const Row(
                          children: [
                            Text(
                              'Lihat Semua',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.black,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Transaction List with Cubit State ──
              BlocBuilder<TransactionCubit, TransactionState>(
                builder: (context, state) {
                  if (state is TransactionLoading) {
                    return SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => const Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: BrutalSkeletonCard(),
                          ),
                          childCount: 3,
                        ),
                      ),
                    );
                  }

                  if (state is TransactionError) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: BrutalistCard(
                          backgroundColor: AppColors.paleYellow,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                state.message,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              BrutalistButton(
                                text: 'COBA LAGI',
                                backgroundColor: AppColors.black,
                                textColor: AppColors.white,
                                onPressed: () => context.read<TransactionCubit>().loadTransactions(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final transactions = (state is TransactionListLoaded)
                      ? state.transactions
                      : context.read<TransactionCubit>().currentList;

                  if (transactions.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            border: Border.all(color: AppColors.black, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: AppColors.black, offset: Offset(4, 4)),
                            ],
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.inbox_rounded, size: 48, color: AppColors.textSecondary),
                                const SizedBox(height: 8),
                                Text(
                                  'Belum ada transaksi.',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final displayList = transactions.take(5).toList();

                  return SliverPadding(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final trx = displayList[index];
                          final lightColors = [AppColors.white, AppColors.paleYellow, AppColors.lightBlue];
                          final bgColor = lightColors[index % lightColors.length];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: BrutalistBounce(
                              onTap: () => context.push('/transaction/${trx.id}'),
                              child: BrutalistCard(
                                backgroundColor: bgColor,
                                padding: const EdgeInsets.all(16),
                                shadowOffset: const Offset(4, 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: AppColors.getStatusColor(trx.status),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.black, width: 2.5),
                                      ),
                                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.black, size: 28),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            trx.description ?? 'Tanpa Deskripsi',
                                            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w900),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${trx.txCode} • ${_formatDate(trx.createdAt)}',
                                            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.format(trx.amount),
                                          style: AppTextStyles.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        BrutalistBadge(
                                          text: EscrowStateMachine.getStatusLabel(trx.status),
                                          backgroundColor: AppColors.getStatusColor(trx.status),
                                          textColor: AppColors.black,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: displayList.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
