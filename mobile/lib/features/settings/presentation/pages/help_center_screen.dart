import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

import '../../../../core/widgets/brutal_skeleton.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'PUSAT BANTUAN',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: Container(
            color: AppColors.black,
            height: 2.0,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                Text(
                  'PERTANYAAN POPULER',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 20),
                
                if (isLoading)
                  ...List.generate(6, (index) => const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: BrutalSkeleton(width: double.infinity, height: 60),
                  ))
                else ...[
                  _buildFaqItem(
                    question: 'Bagaimana sistem Rekber bekerja?',
                    answer: 'Pembeli mentransfer dana ke sistem Rekber. Dana ditahan dengan aman. Penjual mengirim pesanan. Setelah pembeli mengonfirmasi pesanan sesuai, dana baru diteruskan ke penjual.',
                  ),
                  _buildFaqItem(
                    question: 'Siapa yang menanggung biaya admin (fee)?',
                    answer: 'Biaya admin dapat ditanggung oleh Pembeli, Penjual, atau dibagi dua, tergantung kesepakatan kalian saat inisiasi transaksi (pembuatan kode).',
                  ),
                  _buildFaqItem(
                    question: "Kapan saya harus menekan tombol 'Selesai'?",
                    answer: 'HANYA tekan tombol Selesai jika Anda sudah menerima barang/jasa, mengecek semuanya, dan mengamankan data (jika berupa akun digital). Jangan klik jika masih ada masalah!',
                  ),
                  _buildFaqItem(
                    question: 'Apa itu Masa Garansi?',
                    answer: 'Waktu tunggu (misal 2x24 jam) di mana dana ditahan oleh sistem setelah pesanan dikirim, untuk memastikan tidak ada komplain atau percobaan Hackback.',
                  ),
                  _buildFaqItem(
                    question: 'Bagaimana jika barang tidak sesuai (Dispute)?',
                    answer: "Anda dapat menekan tombol 'Panggil Admin' di dalam ruang chat. Dana akan dibekukan sepenuhnya, dan Admin kami akan masuk sebagai penengah untuk meminta bukti dari kedua pihak.",
                  ),
                  _buildFaqItem(
                    question: 'Bagaimana cara membatalkan transaksi?',
                    answer: 'Transaksi hanya bisa dibatalkan jika kedua belah pihak setuju, atau jika penjual belum merespon dalam batas waktu yang ditentukan. Dana akan otomatis dikembalikan (Refund) ke pembeli.',
                  ),
                  _buildFaqItem(
                    question: 'Berapa lama proses penarikan dana (Withdraw)?',
                    answer: 'Penarikan dana ke rekening bank atau E-Wallet akan diproses dalam waktu 1x24 jam pada hari kerja.',
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.black, width: 2.5)),
            ),
            child: isLoading
                ? const BrutalSkeleton(width: double.infinity, height: 56)
                : BrutalistButton(
                    text: 'CHAT ADMIN (WHATSAPP)',
                    onPressed: () {
                      // WhatsApp logic
                    },
                    backgroundColor: AppColors.success,
                    icon: Icons.chat_bubble_outline_rounded,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({
    required String question,
    required String answer,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.black, width: 2.0),
            boxShadow: const [
              BoxShadow(
                color: AppColors.black,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: ExpansionTile(
            title: Text(
              question,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppColors.black,
              ),
            ),
            iconColor: AppColors.black,
            collapsedIconColor: AppColors.black,
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedAlignment: Alignment.topLeft,
            children: [
              Text(
                answer,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
