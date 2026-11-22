import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadDashboardMetrics();
  }

  String _formatRupiah(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return 'Rp ${buffer.toString().split('').reversed.join('')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'DASHBOARD ADMIN',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppColors.white,
          ),
        ),
        backgroundColor: AppColors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocConsumer<AdminCubit, AdminState>(
        listener: (context, state) {
          if (state is AdminError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AdminLoading) {
            return _buildSkeleton();
          }

          if (state is AdminError && state.isForbidden) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gavel_rounded, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'AKSES DITOLAK',
                      style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.spaceGrotesk(fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }

          final metrics = state is AdminDashboardLoaded ? state : null;
          final held = metrics?.heldAmount ?? 0;
          final gmv = metrics?.gmv ?? 0;
          final fee = metrics?.feeRevenue ?? 0;
          final users = metrics?.newUsers ?? 0;
          final disputes = metrics?.openDisputes ?? 0;
          final withdrawals = metrics?.pendingWithdrawals ?? 0;
          final statusMap = metrics?.transactionsByStatus ?? {};

          return RefreshIndicator(
            onRefresh: () => context.read<AdminCubit>().loadDashboardMetrics(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ringkasan Keuangan Platform',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── HERO CARD (Total Escrow Held) ──
                  _buildHeroCard(
                    title: 'Total Dana Ditahan (Escrow)',
                    value: _formatRupiah(held),
                    subtitle: 'Dana aman dalam transaksi aktif',
                    color: Colors.cyanAccent,
                    icon: Icons.lock_clock_rounded,
                  ),

                  const SizedBox(height: 16),

                  // ── STAT CARDS GRID ──
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.8,
                    children: [
                      _buildStatCard(
                        title: 'Total GMV',
                        value: _formatRupiah(gmv),
                        subtitle: 'Transaksi selesai',
                        color: Colors.yellowAccent,
                        icon: Icons.trending_up_rounded,
                      ),
                      _buildStatCard(
                        title: 'Pendapatan Fee',
                        value: _formatRupiah(fee),
                        subtitle: 'Total revenue bersih',
                        color: Colors.greenAccent,
                        icon: Icons.account_balance_wallet_rounded,
                      ),
                      _buildStatCard(
                        title: 'Pengguna Baru',
                        value: '$users',
                        subtitle: 'Terdaftar periode ini',
                        color: const Color(0xFFFF70A6),
                        icon: Icons.people_alt_rounded,
                      ),
                      _buildStatCard(
                        title: 'Sengketa Terbuka',
                        value: '$disputes',
                        subtitle: 'Perlu moderasi',
                        color: Colors.orangeAccent,
                        icon: Icons.gavel_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── QUICK ALERT: PENDING WITHDRAWALS ──
                  if (withdrawals > 0)
                    BrutalistCard(
                      backgroundColor: Colors.amberAccent,
                      padding: const EdgeInsets.all(16),
                      onTap: () => context.push('/admin/withdrawals'),
                      child: Row(
                        children: [
                          const Icon(Icons.pending_actions_rounded, color: AppColors.black, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$withdrawals PENARIKAN MENUNGGU PERSETUJUAN',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Ketuk untuk memeriksa dan menyetujui payout.',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  Text(
                    'Tren Distribusi Transaksi',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Frekuensi transaksi berdasarkan status saat ini',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── FL_CHART BAR CHART ──
                  _buildStatusBarChart(statusMap),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBarChart(Map<String, int> statusMap) {
    final statuses = [
      'PENDING',
      'PAID',
      'SHIPPED',
      'COMPLETED',
      'DISPUTED',
      'REFUNDED',
    ];
    final labels = ['PND', 'PAD', 'SHP', 'CMP', 'DSP', 'RFD'];

    int maxY = 5;
    for (final s in statuses) {
      final val = statusMap[s] ?? 0;
      if (val > maxY) maxY = val + 2;
    }

    final barGroups = List.generate(statuses.length, (i) {
      final key = statuses[i];
      final count = (statusMap[key] ?? 0).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count,
            color: _getStatusColor(key),
            width: 22,
            borderRadius: BorderRadius.zero,
            borderSide: const BorderSide(color: AppColors.black, width: 2),
          ),
        ],
      );
    });

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.black, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.black,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY.toDouble(),
          barGroups: barGroups,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (val) => FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: const Border(
              left: BorderSide(color: AppColors.black, width: 2),
              bottom: BorderSide(color: AppColors.black, width: 2),
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (val, meta) => Text(
                  val.toInt().toString(),
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx >= 0 && idx < labels.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        labels[idx],
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return AppColors.tealGreen;
      case 'PAID':
      case 'SHIPPED':
        return Colors.cyanAccent;
      case 'DISPUTED':
        return Colors.redAccent;
      case 'REFUNDED':
        return Colors.orangeAccent;
      default:
        return Colors.yellowAccent;
    }
  }

  Widget _buildHeroCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return BrutalistCard(
      backgroundColor: color,
      padding: const EdgeInsets.all(20),
      borderRadius: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(icon, color: AppColors.black, size: 28),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w900,
              fontSize: 26,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.black.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return BrutalistCard(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.black),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppColors.black,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: AppColors.black.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          BrutalSkeleton(width: double.infinity, height: 120),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: BrutalSkeleton(width: double.infinity, height: 90)),
              SizedBox(width: 12),
              Expanded(child: BrutalSkeleton(width: double.infinity, height: 90)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: BrutalSkeleton(width: double.infinity, height: 90)),
              SizedBox(width: 12),
              Expanded(child: BrutalSkeleton(width: double.infinity, height: 90)),
            ],
          ),
          SizedBox(height: 24),
          BrutalSkeleton(width: double.infinity, height: 200),
        ],
      ),
    );
  }
}
