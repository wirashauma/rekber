import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

class WithdrawPage extends StatelessWidget {
  const WithdrawPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TARIK DANA'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrutalistCard(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo Tersedia',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Rp 2.500.000',
                    style: AppTextStyles.h1,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Nominal Penarikan', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Min. Rp 10.000',
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 24),
            const Text('Rekening Bank', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Nama Bank (e.g. BCA, Mandiri)',
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Nomor Rekening',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Nama Pemilik Rekening',
              ),
            ),
            const SizedBox(height: 40),
            BrutalistButton(
              text: 'TARIK DANA SEKARANG',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Permintaan penarikan dikirim!')),
                );
              },
              backgroundColor: AppColors.primary,
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Proses penarikan memakan waktu 1-3 hari kerja.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
