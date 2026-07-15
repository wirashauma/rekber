import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

class AutoScrollBanner extends StatefulWidget {
  const AutoScrollBanner({super.key});

  @override
  State<AutoScrollBanner> createState() => _AutoScrollBannerState();
}

class _AutoScrollBannerState extends State<AutoScrollBanner> {
  late final PageController _pageController;
  Timer? _timer;
  late int _currentPage;

  final List<Map<String, dynamic>> _banners = [
    {
      'color': AppColors.mustardYellow,
      'text': 'Awas Hackback! \nAmankan data sebelum klik Selesai.',
      'textColor': AppColors.black,
      'icon': Icons.security,
      'iconBg': AppColors.deepPurple,
      'iconColor': Colors.white,
    },
    {
      'color': const Color(0xFF81D4FA), // Cyan
      'text': 'Wajib Video Unboxing! \n Syarat mutlak klaim garansi.',
      'textColor': AppColors.black,
      'icon': Icons.inventory_2,
      'iconBg': AppColors.mustardYellow,
      'iconColor': AppColors.black,
    },
    {
      'color': const Color(0xFFFF2E63), // Pink/Red
      'text': 'Penjual Pantang Minta Password. \n Hati-hati Penipuan!',
      'textColor': Colors.white,
      'icon': Icons.warning_amber_rounded,
      'iconBg': AppColors.neonGreen,
      'iconColor': AppColors.black,
    },
    {
      'color': const Color(0xFFB4E600), // Green
      'text': 'Cek File Jasamu! \n Pastikan tuntas sebelum dana cair.',
      'textColor': AppColors.black,
      'icon': Icons.handshake_rounded,
      'iconBg': const Color(0xFFFF6B6B),
      'iconColor': Colors.white,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Start at a high number for infinite-like scrolling
    _currentPage = 1000 * _banners.length;
    _pageController = PageController(initialPage: _currentPage);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_pageController.hasClients) {
        _currentPage++;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 130, // Reduced height as content moves up
      child: PageView.builder(
        controller: _pageController,
        clipBehavior: Clip.none,
        onPageChanged: (index) => _currentPage = index,
        // No itemCount for true infinite loop with builder
        itemBuilder: (context, index) {
          final banner = _banners[index % _banners.length];
          return Padding(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 40.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main Banner Card
                Container(
                  width: double.infinity,
                  height: 80,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  decoration: BoxDecoration(
                    color: banner['color'],
                    border: Border.all(color: AppColors.black, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.black,
                        offset: Offset(4, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      banner['text'],
                      style: GoogleFonts.spaceGrotesk(
                        color: banner['textColor'],
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Monster Peeking in the center (Front Layer)
                Positioned(
                  top: -52,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Image.asset(
                      index % 2 == 0
                          ? 'assets/images/monster1.png'
                          : 'assets/images/monster2.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
