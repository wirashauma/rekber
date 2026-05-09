import 'package:flutter/material.dart';
import 'package:rekber/core/constants/app_colors.dart';
import 'package:rekber/core/widgets/brutalist_widgets.dart';
import 'home_page.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../transaction/presentation/pages/create_room_page.dart';
import '../../../transaction/presentation/pages/history_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const HistoryPage(), // Temporary "Transaksi" page
    const CreateRoomPage(), // FAB page
    const Center(child: Text('AI Feature Coming Soon!', style: AppTextStyles.h2)), // AI Placeholder
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _BrutalistBottomNav(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class _BrutalistBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _BrutalistBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 95,
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.black, width: 3)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Nav Items
          Row(
            children: [
              _navItem(0, Icons.home_rounded, 'Beranda'),
              _navItem(1, Icons.chat_bubble_rounded, 'Chat'),
              const SizedBox(width: 80), // Middle space
              _navItem(3, Icons.auto_awesome_rounded, 'AI'),
              _navItem(4, Icons.settings_rounded, 'Pengaturan'),
            ],
          ),
          // FAB
          Positioned(
            top: -25,
            child: GestureDetector(
              onTap: () => onTap(2),
              child: const SizedBox(
                width: 75,
                height: 75,
                child: BrutalistCard(
                  backgroundColor: AppColors.white,
                  shape: BoxShape.circle,
                  shadowOffset: Offset(4, 4),
                  padding: EdgeInsets.zero,
                  child: Center(
                    child: Icon(Icons.add_rounded, size: 40, color: AppColors.black),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.black,
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


