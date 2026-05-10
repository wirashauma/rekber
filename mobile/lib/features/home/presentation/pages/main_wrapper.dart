import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:rekber/core/constants/app_colors.dart';
import 'package:rekber/core/widgets/brutalist_widgets.dart';
import 'home_page.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../transaction/presentation/pages/buat_room_screen.dart';
import '../../../transaction/presentation/pages/history_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../chat/presentation/pages/ai_assistant_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomePage(),
      const HistoryPage(), // Temporary "Transaksi" page
      const BuatRoomScreen(), // FAB page
      const AiAssistantScreen(),
      const SettingsPage(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: pages[_currentIndex],
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
              child: SizedBox(
                width: 75,
                height: 75,
                child: BrutalistCard(
                  backgroundColor: AppColors.white,
                  shape: BoxShape.circle,
                  shadowOffset: const Offset(4, 4),
                  padding: EdgeInsets.zero,
                  child: Center(
                    child: Icon(
                      Icons.add_rounded, 
                      size: 40, 
                      color: currentIndex == 2 ? AppColors.tealGreen : AppColors.black
                    ),
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
              color: isSelected ? AppColors.tealGreen : AppColors.black,
              size: 26,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                color: isSelected ? AppColors.tealGreen : AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


