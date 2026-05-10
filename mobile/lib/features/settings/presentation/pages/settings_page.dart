import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

import '../../../../core/widgets/brutal_skeleton.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PENGATURAN'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Profile Header
            isLoading
                ? const BrutalSkeleton(width: double.infinity, height: 110, borderRadius: 0)
                : const BrutalistCard(
                    backgroundColor: AppColors.white,
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.person_rounded, size: 40, color: AppColors.black),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Wira Shauma', style: AppTextStyles.h2),
                              Text('wira@example.com', style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            const SizedBox(height: 32),
            
            // Settings List
            if (isLoading)
              ...List.generate(5, (index) => const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: BrutalSkeleton(width: double.infinity, height: 60, borderRadius: 0),
              ))
            else ...[
              _settingsItem(
                title: 'Edit Profile',
                icon: Icons.person_outline_rounded,
                onTap: () => context.push('/edit-profile'),
              ),
              _settingsItem(
                title: 'KYC Status',
                icon: Icons.verified_user_outlined,
                badge: _buildKYCBadge(true),
                onTap: () => context.push('/kyc'),
              ),
              _settingsItem(
                title: 'Pusat Bantuan',
                icon: Icons.help_outline_rounded,
                onTap: () => context.push('/help-center'),
              ),
              _settingsItem(
                title: 'Keamanan Akun',
                icon: Icons.lock_outline_rounded,
                onTap: () => context.push('/security'),
              ),
              _settingsItem(
                title: 'Syarat & Kebijakan Privasi',
                icon: Icons.policy_outlined,
                onTap: () => context.push('/legal'),
              ),
              const SizedBox(height: 24),
              
              _settingsItem(
                title: 'Keluar (Logout)',
                icon: Icons.logout_rounded,
                textColor: AppColors.error,
                onTap: () {
                  _showLogoutDialog(context);
                },
              ),
            ],
            
            const SizedBox(height: 40),
            const Text(
              'REKBER v1.0.0 (BETA)',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsItem({
    required String title,
    required IconData icon,
    Widget? badge,
    Color textColor = AppColors.black,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: BrutalistCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shadowOffset: const Offset(3, 3),
        borderWidth: 2,
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: textColor,
              ),
            ),
            const Spacer(),
            if (badge != null) badge,
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildKYCBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isVerified ? AppColors.success : AppColors.warning,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.black, width: 2),
      ),
      child: Text(
        isVerified ? 'VERIFIED' : 'PENDING',
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.black),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.black, width: 4),
        ),
        title: const Text('LOGOUT?', style: AppTextStyles.h2),
        content: const Text('Yakin mau keluar dari aplikasi?', style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL', style: TextStyle(color: AppColors.black, fontWeight: FontWeight.w900)),
          ),
          BrutalistButton(
            text: 'YA, KELUAR',
            onPressed: () {
              Navigator.pop(context);
              // Implementation for actual logout
            },
            backgroundColor: AppColors.error,
          ),
        ],
      ),
    );
  }
}
