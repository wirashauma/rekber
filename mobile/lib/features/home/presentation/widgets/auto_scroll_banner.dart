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
      height: 110, // Increased to accommodate overlapping icon
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => _currentPage = index,
        // No itemCount for true infinite loop with builder
        itemBuilder: (context, index) {
          final banner = _banners[index % _banners.length];
          return Padding(
            padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 15.0),
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
                
                // Overlapping Icon Box
                Positioned(
                  top: -12,
                  left: 20,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: banner['iconBg'],
                      border: Border.all(color: AppColors.black, width: 2.0),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.black,
                          offset: Offset(3, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      banner['icon'],
                      color: banner['iconColor'],
                      size: 22,
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


