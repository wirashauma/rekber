import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

import '../../../../core/widgets/brutal_skeleton.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
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
          'KEAMANAN AKUN',
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
            Text(
              'GANTI PASSWORD',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 24),
            
            if (isLoading)
              ...List.generate(3, (index) => const Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: BrutalSkeleton(width: double.infinity, height: 56),
              ))
            else ...[
              _buildLabel('Password Lama'),
              const BrutalistTextField(
                hintText: 'Masukkan password saat ini',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
              ),
              const SizedBox(height: 20),
              
              _buildLabel('Password Baru'),
              const BrutalistTextField(
                hintText: 'Minimal 8 karakter',
                prefixIcon: Icons.lock_reset_rounded,
                obscureText: true,
              ),
              const SizedBox(height: 20),
              
              _buildLabel('Konfirmasi Password Baru'),
              const BrutalistTextField(
                hintText: 'Ulangi password baru',
                prefixIcon: Icons.verified_user_outlined,
                obscureText: true,
              ),
            ],
            
            const SizedBox(height: 40),
            
            Text(
              'TRANSAKSI',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 16),
            
            isLoading
                ? const BrutalSkeleton(width: double.infinity, height: 60)
                : BrutalistCard(
                    backgroundColor: AppColors.paleYellow,
                    onTap: () {
                      // Change PIN logic
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.pin_rounded, color: AppColors.black),
                        const SizedBox(width: 16),
                        Text(
                          'Ubah PIN Transaksi',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.black),
                      ],
                    ),
                  ),
            
            const SizedBox(height: 48),
            
            isLoading
                ? const BrutalSkeleton(width: double.infinity, height: 56)
                : BrutalistButton(
                    text: 'PERBARUI KEAMANAN',
                    onPressed: () {
                      // Update security logic
                    },
                    backgroundColor: AppColors.hotPink,
                    textColor: AppColors.white,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          color: AppColors.black,
        ),
      ),
    );
  }
}
