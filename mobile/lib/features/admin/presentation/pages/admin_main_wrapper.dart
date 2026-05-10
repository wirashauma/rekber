import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class AdminMainWrapper extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AdminMainWrapper({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        height: 90,
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(
            top: BorderSide(color: AppColors.black, width: 3.0),
          ),
        ),
        child: Row(
          children: [
            _buildNavItem(0, Icons.dashboard_rounded, 'Dashboard'),
            _buildNavItem(1, Icons.gavel_rounded, 'Dispute'),
            _buildNavItem(2, Icons.verified_user_rounded, 'KYC'),
            _buildNavItem(3, Icons.settings_rounded, 'Pengaturan'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = navigationShell.currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.tealGreen : AppColors.black,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? AppColors.tealGreen : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
