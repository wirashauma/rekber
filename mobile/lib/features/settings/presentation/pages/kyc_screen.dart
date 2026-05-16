import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'VERIFIKASI IDENTITAS',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            isLoading
                ? const BrutalSkeleton(width: double.infinity, height: 80)
                : BrutalistCard(
                    backgroundColor: AppColors.mustardYellow,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.black, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BELUM VERIFIKASI',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: AppColors.black,
                                ),
                              ),
                              Text(
                                'Verifikasi KTP untuk transaksi lebih aman.',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: AppColors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            const SizedBox(height: 32),
            
            Text(
              'DOKUMEN DIPERLUKAN',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 20),
            
            isLoading
                ? const BrutalSkeleton(width: double.infinity, height: 180)
                : _buildUploadBox(
                    title: 'Upload Foto KTP',
                    subtitle: 'Pastikan teks terbaca jelas',
                    icon: Icons.badge_outlined,
                    onTap: () {},
                  ),
            const SizedBox(height: 24),
            
            isLoading
                ? const BrutalSkeleton(width: double.infinity, height: 180)
                : _buildUploadBox(
                    title: 'Upload Selfie dengan KTP',
                    subtitle: 'Wajah dan KTP harus terlihat',
                    icon: Icons.camera_front_outlined,
                    onTap: () {},
                  ),
            
            const SizedBox(height: 48),
            
            isLoading
                ? const BrutalSkeleton(width: double.infinity, height: 56)
                : BrutalistButton(
                    text: 'KIRIM DOKUMEN',
                    onPressed: () {
                      // Submit logic
                    },
                    backgroundColor: AppColors.brightBlue,
                    textColor: AppColors.white,
                  ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Data Anda aman & terenkripsi',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadBox({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return BrutalistBounce(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.black, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: AppColors.black,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.black),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.paleYellow,
                border: Border.all(color: AppColors.black, width: 1.5),
              ),
              child: Text(
                'PILIH FILE',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
