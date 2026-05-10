import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/constants/app_colors.dart';

class AdminKycScreen extends StatefulWidget {
  const AdminKycScreen({super.key});

  @override
  State<AdminKycScreen> createState() => _AdminKycScreenState();
}

class _AdminKycScreenState extends State<AdminKycScreen> {
  String selectedFilter = 'Menunggu';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'APPROVAL KYC',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppColors.black,
          ),
        ),
        backgroundColor: Colors.greenAccent,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: AppColors.black, height: 2),
        ),
      ),
      body: Column(
        children: [
          // ── FILTER TABS ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.black, width: 2),
              ),
            ),
            child: Row(
              children: [
                _buildFilterChip('Menunggu'),
                const SizedBox(width: 12),
                _buildFilterChip('Riwayat'),
              ],
            ),
          ),

          // ── KYC LIST ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: selectedFilter == 'Menunggu' ? 4 : 2,
              itemBuilder: (context, index) {
                return _buildKycCard(context, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = selectedFilter == label;
    return BrutalistBounce(
      onTap: () => setState(() => selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellowAccent : AppColors.white,
          border: Border.all(color: AppColors.black, width: 2),
          boxShadow: isSelected
              ? null
              : const [
                  BoxShadow(
                    color: AppColors.black,
                    offset: Offset(2, 2),
                  ),
                ],
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildKycCard(BuildContext context, int index) {
    final List<String> names = [
      'Andi Wijaya',
      'Siti Aminah',
      'Rizky Pratama',
      'Dewi Lestari',
    ];
    final String currentName = names[index % names.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: BrutalistCard(
        backgroundColor: AppColors.white,
        padding: const EdgeInsets.all(16),
        borderRadius: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    border: Border.all(color: AppColors.black, width: 2),
                  ),
                  child: const Icon(Icons.person, color: AppColors.black),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentName,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Diajukan: 10 Mei 2026',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedFilter == 'Riwayat')
                  const BrutalistBadge(
                    text: 'VERIFIED',
                    backgroundColor: Colors.greenAccent,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            
            // ── TEXT DATA COMPARISON ──
            _buildDataField('NIK', '327301280991000${index + 1}'),
            const SizedBox(height: 12),
            _buildDataField('NAMA LENGKAP', currentName.toUpperCase()),
            
            const SizedBox(height: 20),
            
            // ── IMAGE EVIDENCE ──
            Row(
              children: [
                _buildImageBox(context, 'KTP / IDENTITAS', Icons.badge_rounded),
                const SizedBox(width: 12),
                _buildImageBox(context, 'SELFIE DENGAN KTP', Icons.face_retouching_natural_rounded),
              ],
            ),
            
            if (selectedFilter == 'Menunggu') ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: BrutalistButton(
                      text: 'TERIMA',
                      backgroundColor: Colors.greenAccent,
                      height: 50,
                      borderRadius: 4,
                      onPressed: () => _showApprovalDialog(context, currentName),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrutalistButton(
                      text: 'TOLAK',
                      backgroundColor: Colors.redAccent,
                      height: 50,
                      borderRadius: 4,
                      onPressed: () => _showRejectionModal(context),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: AppColors.black, width: 1.5),
          ),
          child: Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageBox(BuildContext context, String label, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          BrutalistBounce(
            onTap: () => _showImageDialog(context, label, icon),
            child: Container(
              height: 90,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border.all(color: AppColors.black, width: 2),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(icon, color: Colors.grey[400], size: 32),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Icon(Icons.zoom_in_rounded, size: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, String title, IconData icon) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrutalistCard(
              backgroundColor: AppColors.white,
              padding: const EdgeInsets.all(8),
              borderRadius: 4,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          title,
                          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border.all(color: AppColors.black, width: 2),
                    ),
                    child: InteractiveViewer(
                      child: Center(
                        child: Icon(icon, size: 120, color: Colors.grey[300]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                top: BorderSide(color: AppColors.black, width: 4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALASAN PENOLAKAN',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                _rejectionOption(setModalState, 'Foto KTP buram atau tidak terbaca'),
                _rejectionOption(setModalState, 'Selfie tidak cocok dengan KTP'),
                _rejectionOption(setModalState, 'Bagian KTP terpotong'),
                _rejectionOption(setModalState, 'Identitas dicurigai palsu'),
                const SizedBox(height: 20),
                const BrutalistTextField(
                  hintText: 'Catatan Tambahan (Opsional)',
                  prefixIcon: Icons.note_add_rounded,
                ),
                const SizedBox(height: 24),
                BrutalistButton(
                  text: 'KONFIRMASI TOLAK',
                  backgroundColor: Colors.redAccent,
                  textColor: AppColors.white,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _rejectionOption(StateSetter setModalState, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: BrutalistCard(
        backgroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: 4,
        onTap: () {}, // Would toggle selection logic in real app
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.black, width: 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showApprovalDialog(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
            side: BorderSide(color: AppColors.black, width: 3)),
        title: Text(
          'KONFIRMASI',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Verifikasi identitas $name? Akun ini akan mendapatkan akses penuh.',
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
            text: 'YA, TERIMA',
            backgroundColor: Colors.greenAccent,
            height: 40,
            width: 140,
            borderRadius: 4,
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('User Berhasil Diverifikasi'),
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
