import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/constants/app_colors.dart';

class AdminUserManageScreen extends StatefulWidget {
  const AdminUserManageScreen({super.key});

  @override
  State<AdminUserManageScreen> createState() => _AdminUserManageScreenState();
}

class _AdminUserManageScreenState extends State<AdminUserManageScreen> {
  final TextEditingController _searchController = TextEditingController();

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
          'KELOLA PENGGUNA',
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
      body: Column(
        children: [
          // ── SEARCH BAR ──
          Padding(
            padding: const EdgeInsets.all(20),
            child: BrutalistTextField(
              controller: _searchController,
              hintText: 'Cari nama atau email...',
              prefixIcon: Icons.search_rounded,
            ),
          ),

          // ── USER LIST ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              itemCount: 10,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: BrutalistCard(
                    backgroundColor: AppColors.white,
                    padding: const EdgeInsets.all(16),
                    borderRadius: 4,
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          radius: 20,
                          child: const Icon(Icons.person, color: AppColors.black),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Account #${index + 1}',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'user${index + 1}@example.com',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        BrutalistButton(
                          text: 'BAN',
                          backgroundColor: Colors.redAccent,
                          textColor: Colors.white,
                          height: 35,
                          width: 60,
                          borderRadius: 4,
                          onPressed: () => _showBanConfirmation(context, 'User Account #${index + 1}'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showBanConfirmation(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
            side: BorderSide(color: AppColors.black, width: 3)),
        title: Text(
          'BLOKIR PENGGUNA',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Apakah Anda yakin ingin memblokir akses $name? Pengguna ini tidak akan bisa login kembali.',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'BATAL',
              style: GoogleFonts.spaceGrotesk(
                  color: Colors.grey, fontWeight: FontWeight.w900),
            ),
          ),
          BrutalistButton(
            text: 'YA, BLOKIR',
            backgroundColor: Colors.black,
            textColor: Colors.white,
            height: 40,
            width: 120,
            borderRadius: 4,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pengguna Berhasil Diblokir'),
                  backgroundColor: AppColors.black,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
