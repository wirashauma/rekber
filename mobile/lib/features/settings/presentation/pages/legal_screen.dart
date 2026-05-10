import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'INFORMASI LEGAL',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
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
            // Prominent Security Card (Xendit Clause)
            BrutalistCard(
              backgroundColor: Colors.white,
              borderWidth: 2.5,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_rounded, color: Colors.black, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'KEAMANAN DANA (ESCROW)',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Seluruh dana transaksi ditahan secara otomatis dan aman oleh sistem melalui mitra Payment Gateway resmi berlisensi (Xendit). Pengembang atau pihak aplikasi tidak pernah memegang, menyimpan, atau memutar dana pengguna secara pribadi dalam rekening pribadi.',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            _buildLegalSection(
              title: 'Syarat Ketentuan Penggunaan Aplikasi',
              content: 'Dengan menggunakan aplikasi REKBER, Anda setuju untuk mematuhi seluruh aturan transaksi yang berlaku. Pengguna wajib memberikan data yang valid untuk proses verifikasi KYC. Segala bentuk penyalahgunaan platform untuk tindakan ilegal akan dilaporkan kepada pihak berwajib.',
            ),
            const SizedBox(height: 20),

            _buildLegalSection(
              title: 'Kebijakan Privasi & Data Pengguna',
              content: 'Kami menghargai privasi Anda. Data pribadi yang dikumpulkan hanya digunakan untuk keperluan verifikasi keamanan dan kelancaran transaksi. Kami tidak akan menjual atau membagikan data Anda kepada pihak ketiga tanpa persetujuan eksplisit, kecuali diwajibkan oleh hukum.',
            ),
            const SizedBox(height: 20),

            _buildLegalSection(
              title: 'Penyelesaian Sengketa (Dispute)',
              content: 'Jika terjadi ketidaksesuaian dalam transaksi, pengguna dapat mengajukan sengketa. Tim mediator kami akan meninjau bukti dari kedua belah pihak (Penjual & Pembeli) sebelum mengambil keputusan final mengenai pelepasan atau pengembalian dana.',
            ),
            
            const SizedBox(height: 40),
            Center(
              child: Text(
                'Terakhir Diperbarui: 10 Mei 2026',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalSection({required String title, required String content}) {
    return BrutalistCard(
      backgroundColor: Colors.white,
      borderWidth: 2.0,
      padding: const EdgeInsets.all(16),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            title.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Colors.black,
            ),
          ),
          iconColor: Colors.black,
          collapsedIconColor: Colors.black,
          children: [
            const Divider(color: Colors.black, thickness: 1),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                content,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: Colors.black,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
