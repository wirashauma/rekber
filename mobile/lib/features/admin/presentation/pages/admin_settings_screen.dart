import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';

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
            'PERSETUJUAN PENARIKAN',
            Icons.payments_rounded,
            () => context.push('/admin/withdrawals'),
          ),
          _buildMenuButton(
            context,
            'KELOLA PENGGUNA',
            Icons.people_alt_rounded,
            () => context.push('/admin/settings/users'),
          ),
          _buildMenuButton(
            context,
            'SISTEM & LOG AUDIT',
            Icons.history_edu_rounded,
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

  void _showAdminLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.black, width: 3),
        ),
        title: Text(
          'KELUAR MODE ADMIN?',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Sesi login administrator Anda akan dihentikan.',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'BATAL',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.grey,
                fontWeight: FontWeight.w900,
              ),
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
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
          ),
        ],
      ),
    );
  }
}
