import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

class CreateRoomPage extends StatelessWidget {
  const CreateRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('BUAT ROOM ESCROW'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informasi Transaksi', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Judul Transaksi (e.g. Jual Akun Game)',
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Deskripsi Detail Barang/Jasa',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            const Text('Nominal & Lawan Transaksi', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Jumlah Pembayaran',
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Username/Email Lawan Transaksi',
                prefixIcon: Icon(Icons.person_search_rounded, color: AppColors.black),
              ),
            ),
            const SizedBox(height: 32),
            const BrutalistCard(
              backgroundColor: AppColors.secondary,
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dana akan ditahan oleh sistem sampai transaksi dinyatakan selesai oleh kedua belah pihak.',
                      style: TextStyle(color: AppColors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            BrutalistButton(
              text: 'BAYAR & BUAT ROOM',
              onPressed: () {
                // Mock redirect to payment gateway
                _showMockPayment(context);
              },
              backgroundColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showMockPayment(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: AppColors.black, width: 4),
            left: BorderSide(color: AppColors.black, width: 4),
            right: BorderSide(color: AppColors.black, width: 4),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('PAYMENT GATEWAY', style: AppTextStyles.h2),
            const Divider(color: AppColors.black, thickness: 3),
            const SizedBox(height: 20),
            const Text('Pilih Metode Pembayaran', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            _paymentOption('QRIS / E-Wallet', Icons.qr_code_scanner_rounded),
            _paymentOption('Bank Transfer (Virtual Account)', Icons.account_balance_rounded),
            _paymentOption('Credit Card', Icons.credit_card_rounded),
            const Spacer(),
            BrutalistButton(
              text: 'KONFIRMASI PEMBAYARAN',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pembayaran Berhasil! Room Chat Terbuat.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentOption(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: BrutalistCard(
        padding: const EdgeInsets.all(16),
        shadowOffset: const Offset(3, 3),
        borderWidth: 2,
        child: Row(
          children: [
            Icon(icon, color: AppColors.black),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const Spacer(),
            const Icon(Icons.radio_button_off_rounded),
          ],
        ),
      ),
    );
  }
}
