import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

class TarikDanaScreen extends StatefulWidget {
  const TarikDanaScreen({super.key});

  @override
  State<TarikDanaScreen> createState() => _TarikDanaScreenState();
}

class _TarikDanaScreenState extends State<TarikDanaScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedAccount = 'BCA - 12345678 a.n. Rizky';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.neonGreen,
        elevation: 0,
        title: Text(
          'TARIK DANA (WITHDRAW)',
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
            BrutalistCard(
              backgroundColor: AppColors.deepPurple,
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo Aktif',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rp750.000',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Nominal Penarikan',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            BrutalistTextField(
              hintText: 'Masukkan nominal penarikan',
              prefixIcon: Icons.outbox_rounded,
              controller: _amountController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            Text(
              'Rekening Tujuan',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                // Show bottom sheet or dialog to pick account
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 2.0),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, color: Colors.black),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedAccount,
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            BrutalistButton(
              text: 'TARIK SEKARANG',
              onPressed: () {
                // Action
              },
              backgroundColor: Colors.black,
              textColor: Colors.white,
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Estimasi proses: 1x24 jam kerja',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
