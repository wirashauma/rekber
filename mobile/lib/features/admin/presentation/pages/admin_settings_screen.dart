import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'PENGATURAN ADMIN',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppColors.black,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: AppColors.black, height: 2),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildMenuButton(
            context,
            'KONTROL FINANSIAL',
            Icons.account_balance_rounded,
            () => context.push('/admin/settings/financial'),
          ),
          _buildMenuButton(
            context,
            'BROADCAST PENGUMUMAN',
            Icons.campaign_rounded,
            () => _showAdminBroadcastDialog(context),
          ),
          _buildMenuButton(
            context,
            'KELOLA PENGGUNA',
            Icons.people_alt_rounded,
            () => context.push('/admin/settings/users'),
          ),
          _buildMenuButton(
            context,
            'SISTEM & KEAMANAN',
            Icons.settings_suggest_rounded,
            () => context.push('/admin/settings/system'),
          ),
          const SizedBox(height: 24),
          _buildMenuButton(
            context,
            'KELUAR (LOGOUT)',
            Icons.logout_rounded,
            () => _showAdminLogoutDialog(context),
            isDanger: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onTap, {
    bool isDanger = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: BrutalistButton(
        text: text,
        backgroundColor: isDanger ? Colors.redAccent : AppColors.white,
        textColor: isDanger ? Colors.white : AppColors.black,
        icon: icon,
        height: 60,
        borderRadius: 4,
        onPressed: onTap,
      ),
    );
  }

  void _showAdminBroadcastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
            side: BorderSide(color: AppColors.black, width: 3)),
        title: Text(
          'BROADCAST PESAN',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrutalistTextField(
              hintText: 'Tulis pesan pengumuman...',
              prefixIcon: Icons.message_rounded,
            ),
            const SizedBox(height: 20),
            Text(
              'Pesan ini akan dikirimkan ke semua pengguna terdaftar.',
              style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'BATAL',
              style: GoogleFonts.spaceGrotesk(
                  color: Colors.grey, fontWeight: FontWeight.w900),
            ),
          ),
          BrutalistButton(
            text: 'KIRIM SEKARANG',
            backgroundColor: Colors.cyanAccent,
            height: 40,
            width: 150,
            borderRadius: 4,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pengumuman Berhasil Dikirim'),
                  backgroundColor: AppColors.black,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAdminLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
            side: BorderSide(color: AppColors.black, width: 3)),
        title: Text(
          'KELUAR MODE ADMIN?',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Anda akan dikembalikan ke halaman Login.',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'BATAL',
              style: GoogleFonts.spaceGrotesk(
                  color: Colors.grey, fontWeight: FontWeight.w900),
            ),
          ),
          BrutalistButton(
            text: 'YA, KELUAR',
            backgroundColor: Colors.redAccent,
            textColor: Colors.white,
            height: 40,
            width: 140,
            borderRadius: 4,
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
