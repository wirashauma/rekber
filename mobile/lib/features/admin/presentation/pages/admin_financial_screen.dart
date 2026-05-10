import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/constants/app_colors.dart';

class AdminFinancialScreen extends StatelessWidget {
  const AdminFinancialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'KONTROL FINANSIAL',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: AppColors.black, height: 2),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Fee Platform (%)'),
            const BrutalistTextField(
              hintText: 'Contoh: 2.0',
              prefixIcon: Icons.percent_rounded,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            _buildLabel('Batas Transaksi (IDR)'),
            Row(
              children: [
                const Expanded(
                  child: BrutalistTextField(
                    hintText: 'Min: 10.000',
                    prefixIcon: Icons.arrow_downward_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: BrutalistTextField(
                    hintText: 'Max: 100.000.000',
                    prefixIcon: Icons.arrow_upward_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            BrutalistButton(
              text: 'SIMPAN PERUBAHAN',
              backgroundColor: Colors.yellowAccent,
              onPressed: () {
                context.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pengaturan Finansial Diperbarui'),
                    backgroundColor: AppColors.black,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: AppColors.black,
        ),
      ),
    );
  }
}
