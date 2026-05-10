import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/utils/currency_formatter.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> riwayat = [
      {
        'title': 'Beli Akun Mobile Legends',
        'price': 250000,
        'status': 'SELESAI',
        'date': '12 Apr 2024',
        'color': AppColors.neonGreen,
      },
      {
        'title': 'Top Up Diamond Free Fire',
        'price': 50000,
        'status': 'DIBATALKAN',
        'date': '10 Apr 2024',
        'color': AppColors.hotPink,
      },
      {
        'title': 'Jasa GB Rank Valorant',
        'price': 150000,
        'status': 'SELESAI',
        'date': '08 Apr 2024',
        'color': AppColors.neonGreen,
      },
      {
        'title': 'Beli Script Website Portfolio',
        'price': 450000,
        'status': 'SELESAI',
        'date': '05 Apr 2024',
        'color': AppColors.neonGreen,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'RIWAYAT SELESAI',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const Border(
          bottom: BorderSide(color: Colors.black, width: 2.0),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: isLoading ? 5 : riwayat.length,
        itemBuilder: (context, index) {
          if (isLoading) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: BrutalSkeletonCard(),
            );
          }

          final item = riwayat[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: BrutalistCard(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: item['color'],
                      border: Border.all(color: Colors.black, width: 2.0),
                    ),
                    child: Icon(
                      item['status'] == 'SELESAI' 
                        ? Icons.check_circle_outline_rounded 
                        : Icons.cancel_outlined,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'],
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item['date'],
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.format(item['price']),
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item['color'],
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: Text(
                          item['status'],
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
