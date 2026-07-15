import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/constants/app_colors.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ringkasan Keuangan',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 16),
            
            // ── HERO CARD (Total Escrow) ──
            _buildHeroCard(
              title: 'Total Dana Ditahan (Escrow)',
              value: 'Rp 450.000.000',
              subtitle: '128 Transaksi Berjalan',
              color: Colors.cyanAccent,
              icon: Icons.lock_clock_rounded,
            ),
            
            const SizedBox(height: 16),
            
            // ── COMPACT STAT CARDS GRID ──
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.1,
              children: [
                _buildStatCard(
                  title: 'Total GMV',
                  value: 'Rp 1.2M',
                  subtitle: 'Bulan ini',
                  color: Colors.yellowAccent,
                  icon: Icons.trending_up_rounded,
                ),
                _buildStatCard(
                  title: 'Total Fee',
                  value: 'Rp 24jt',
                  subtitle: 'Keuntungan Net',
                  color: Colors.greenAccent,
                  icon: Icons.account_balance_wallet_rounded,
                ),
                _buildStatCard(
                  title: 'User Aktif',
                  value: '1,284',
                  subtitle: '+12% vs Kemarin',
                  color: const Color(0xFFFF70A6), // Vibrant Pink
                  icon: Icons.people_alt_rounded,
                ),
                _buildStatCard(
                  title: 'Sengketa',
                  value: '5',
                  subtitle: 'Perlu Tindakan',
                  color: Colors.orangeAccent,
                  icon: Icons.gavel_rounded,
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            Text(
              'Aktivitas Terbaru',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 12),
            
            // ── COMPACT ACTIVITY LIST ──
            _buildActivityItem(
              title: 'Dispute Diajukan',
              description: 'TRX #9921 - Masalah Akun',
              time: '2m ago',
              icon: Icons.warning_rounded,
              iconColor: Colors.redAccent,
            ),
            _buildActivityItem(
              title: 'Pencairan Selesai',
              description: 'Rp 1.200.000 ke @user88',
              time: '15m ago',
              icon: Icons.check_circle_rounded,
              iconColor: Colors.greenAccent,
            ),
            _buildActivityItem(
              title: 'Room Baru Dibuat',
              description: 'TRX #8822 oleh @rizky_s',
              time: '1h ago',
              icon: Icons.add_box_rounded,
              iconColor: Colors.yellowAccent,
            ),
            _buildActivityItem(
              title: 'KYC Terverifikasi',
              description: 'User: @andi_pro - Berhasil',
              time: '2h ago',
              icon: Icons.verified_user_rounded,
              iconColor: Colors.cyanAccent,
            ),
          ],
        ),
      ),
    );
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
                  fontSize: 14,
                  letterSpacing: 1.0,
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
              fontSize: 32,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: AppColors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: AppColors.black, size: 16),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: AppColors.black,
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w700,
              fontSize: 9,
              color: AppColors.black.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required String title,
    required String description,
    required String time,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: BrutalistCard(
        backgroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: 4,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor,
                border: Border.all(color: AppColors.black, width: 2),
              ),
              child: Icon(icon, color: AppColors.black, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              time,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
