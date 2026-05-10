import 'package:flutter/material.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/constants/app_colors.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'DASHBOARD ADMIN',
          style: TextStyle(
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
            const Text(
              'Ringkasan Keuangan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 0.85,
              children: [
                _buildStatCard(
                  title: 'Total GMV',
                  value: 'Rp 1.2M',
                  subtitle: 'Transaksi Sukses',
                  color: Colors.yellowAccent,
                  icon: Icons.trending_up,
                ),
                _buildStatCard(
                  title: 'In Escrow',
                  value: 'Rp 450jt',
                  subtitle: 'Dana Aman',
                  color: Colors.cyanAccent,
                  icon: Icons.lock,
                ),
                _buildStatCard(
                  title: 'Total Fee',
                  value: 'Rp 24jt',
                  subtitle: 'Keuntungan',
                  color: Colors.greenAccent,
                  icon: Icons.account_balance_wallet,
                ),
                _buildStatCard(
                  title: 'User Aktif',
                  value: '1,284',
                  subtitle: 'Total Terdaftar',
                  color: Colors.pinkAccent,
                  icon: Icons.people,
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Aktivitas Terbaru',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 15),
            ...List.generate(3, (index) => _buildActivityItem(index)),
          ],
        ),
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
      padding: const EdgeInsets.all(16),
      borderRadius: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.black, size: 32),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: AppColors.black,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: AppColors.black.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: BrutalistCard(
        backgroundColor: AppColors.white,
        padding: const EdgeInsets.all(12),
        borderRadius: 4,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: index % 2 == 0 ? Colors.blueAccent : Colors.orangeAccent,
                border: Border.all(color: AppColors.black, width: 2),
              ),
              child: Icon(
                index % 2 == 0 ? Icons.payment : Icons.swap_horiz,
                color: AppColors.black,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaksi Baru #8271',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Pembayaran Rp 500.000 terverifikasi',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Text(
              '2m ago',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
