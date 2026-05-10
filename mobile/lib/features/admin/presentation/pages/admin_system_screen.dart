import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/constants/app_colors.dart';

class AdminSystemScreen extends StatefulWidget {
  const AdminSystemScreen({super.key});

  @override
  State<AdminSystemScreen> createState() => _AdminSystemScreenState();
}

class _AdminSystemScreenState extends State<AdminSystemScreen> {
  bool isMaintenanceMode = false;

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
          'SISTEM & KEAMANAN',
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
            _buildLabel('Status Sistem'),
            _buildMaintenanceToggle(),
            const SizedBox(height: 32),
            _buildLabel('Monitoring'),
            BrutalistCard(
              backgroundColor: AppColors.white,
              padding: const EdgeInsets.all(16),
              borderRadius: 4,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Membuka Log Audit...')),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.history_edu_rounded, color: AppColors.black),
                  const SizedBox(width: 12),
                  Text(
                    'LIHAT LOG AUDIT',
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.black),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMaintenanceToggle() {
    return BrutalistBounce(
      onTap: () => setState(() => isMaintenanceMode = !isMaintenanceMode),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMaintenanceMode ? Colors.redAccent : Colors.greenAccent,
          border: Border.all(color: AppColors.black, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: AppColors.black,
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isMaintenanceMode ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: isMaintenanceMode ? Colors.white : AppColors.black,
            ),
            const SizedBox(width: 12),
            Text(
              isMaintenanceMode ? 'SISTEM DITUTUP SEMENTARA' : 'SISTEM BERJALAN NORMAL',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                color: isMaintenanceMode ? Colors.white : AppColors.black,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.black,
                border: Border.all(color: AppColors.white, width: 1),
              ),
              child: Text(
                isMaintenanceMode ? 'ON' : 'OFF',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
