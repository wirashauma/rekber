import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

class InputKodeScreen extends StatefulWidget {
  const InputKodeScreen({super.key});

  @override
  State<InputKodeScreen> createState() => _InputKodeScreenState();
}

class _InputKodeScreenState extends State<InputKodeScreen> {
  final TextEditingController _kodeController = TextEditingController();
  bool _hasSearched = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.mustardYellow,
        elevation: 0,
        title: Text(
          'GABUNG TRANSAKSI',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan Kode Transaksi',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            BrutalistTextField(
              hintText: 'Contoh: TRX-12345',
              prefixIcon: Icons.qr_code_scanner_rounded,
              controller: _kodeController,
            ),
            const SizedBox(height: 16),
            BrutalistButton(
              text: 'CARI TRANSAKSI',
              onPressed: () {
                setState(() => _hasSearched = true);
              },
              backgroundColor: Colors.black,
              textColor: Colors.white,
            ),
            const SizedBox(height: 32),
            if (_hasSearched) ...[
              Text(
                'Hasil Pencarian',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              BrutalistCard(
                backgroundColor: AppColors.paleYellow,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Beli Akun Valorant',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const BrutalistBadge(
                          text: 'PENDING',
                          backgroundColor: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rp450.000',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: AppColors.deepPurple,
                      ),
                    ),
                    const Divider(color: Colors.black, thickness: 2, height: 24),
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.black,
                          radius: 12,
                          child: Icon(Icons.person, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Dibuat oleh: Toko Elektronik',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              BrutalistButton(
                text: 'GABUNG SEKARANG',
                onPressed: () {
                  // Action
                },
                backgroundColor: AppColors.neonGreen,
              ),
            ] else 
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 64, color: Colors.black.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada transaksi dicari',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.bold,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
