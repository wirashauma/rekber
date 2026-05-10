import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

import '../../../../core/widgets/brutal_skeleton.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
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
          'EDIT PROFIL',
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Profile Picture Placeholder
            isLoading
                ? const BrutalSkeleton(width: 120, height: 120, borderRadius: 60)
                : Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.paleYellow,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.black, width: 3.0),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.black,
                                offset: Offset(4, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 60,
                            color: AppColors.black,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: BrutalistBounce(
                            onTap: () {
                              // Pick Image Logic
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.neonGreen,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.black, width: 2.0),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                size: 20,
                                color: AppColors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            const SizedBox(height: 40),
            
            if (isLoading)
              ...List.generate(3, (index) => const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: BrutalSkeleton(width: double.infinity, height: 56),
              ))
            else ...[
              _buildLabel("Nama Lengkap"),
              const BrutalistTextField(
                hintText: "Masukkan nama lengkap",
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 24),
              
              _buildLabel("Email"),
              const BrutalistTextField(
                hintText: "Masukkan email aktif",
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),
              
              _buildLabel("Nomor Telepon"),
              const BrutalistTextField(
                hintText: "Contoh: 08123456789",
                prefixIcon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
              ),
            ],
            
            const SizedBox(height: 48),
            
            isLoading
                ? const BrutalSkeleton(width: double.infinity, height: 56)
                : BrutalistButton(
                    text: "SIMPAN PERUBAHAN",
                    onPressed: () {
                      // Save logic
                    },
                    backgroundColor: AppColors.neonGreen,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: AppColors.black,
          ),
        ),
      ),
    );
  }
}
