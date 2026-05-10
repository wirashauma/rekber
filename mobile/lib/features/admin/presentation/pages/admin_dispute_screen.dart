import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/constants/app_colors.dart';

class AdminDisputeScreen extends StatefulWidget {
  const AdminDisputeScreen({super.key});

  @override
  State<AdminDisputeScreen> createState() => _AdminDisputeScreenState();
}

class _AdminDisputeScreenState extends State<AdminDisputeScreen> {
  String selectedFilter = 'Semua';

  final List<String> filters = [
    'Semua',
    'Urgent (Menunggu)',
    'Investigasi',
    'Selesai'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'MODERASI DISPUTE',
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
          // ── FILTER CHIPS ──
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.black, width: 2),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: BrutalistBounce(
                    onTap: () => setState(() => selectedFilter = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                      child: Center(
                        child: Text(
                          filter.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── DISPUTE LIST ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: 5,
              itemBuilder: (context, index) {
                return _buildDisputeCard(context, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisputeCard(BuildContext context, int index) {
    final txid = 'TXID-#${8270 - index}';
    final List<String> reasons = [
      'Barang tidak sesuai deskripsi',
      'Penjual tidak merespon chat',
      'Akun pembeli mencurigakan',
      'Barang rusak saat pengiriman',
      'Komplain paket kosong',
    ];

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BrutalistBadge(
                  text: 'URGENT',
                  backgroundColor: Colors.yellowAccent,
                ),
                Text(
                  'Diajukan: ${index + 1} jam yang lalu',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              txid,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: Colors.grey[800],
              ),
            ),
            Text(
              reasons[index % reasons.length].toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Pembeli:', 'Budi Santoso (@budi88)'),
            _buildInfoRow('Penjual:', 'Toko Elektronik Makmur'),
            _buildInfoRow('Dana Ditahan:', 'Rp 2.500.000', isBold: true),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BrutalistButton(
                    text: 'MASUK CHAT',
                    backgroundColor: Colors.cyanAccent,
                    height: 45,
                    borderRadius: 4,
                    onPressed: () {
                      context.push('/admin/dispute/chat/$txid');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BrutalistButton(
                    text: 'TINDAKAN',
                    backgroundColor: Colors.orangeAccent,
                    height: 45,
                    borderRadius: 4,
                    onPressed: () => _showActionSheet(context, txid),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context, String txid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
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
                'KEPUTUSAN FINAL ($txid)',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              _actionButton(
                context,
                'CAIRKAN KE PENJUAL',
                Colors.greenAccent,
                AppColors.black,
                () => _confirmAction(context, 'Cairkan ke Penjual?'),
              ),
              const SizedBox(height: 12),
              _actionButton(
                context,
                'REFUND KE PEMBELI',
                Colors.redAccent,
                AppColors.white,
                () => _confirmAction(context, 'Refund ke Pembeli?'),
              ),
              const SizedBox(height: 12),
              _actionButton(
                context,
                'BEKUKAN AKUN PENIPU',
                AppColors.black,
                AppColors.white,
                () => _confirmAction(context, 'Bekukan Akun Ini?'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _actionButton(BuildContext context, String text, Color bg, Color textCol,
      VoidCallback onPressed) {
    return BrutalistButton(
      text: text,
      backgroundColor: bg,
      textColor: textCol,
      height: 55,
      borderRadius: 4,
      onPressed: onPressed,
    );
  }

  void _confirmAction(BuildContext context, String message) {
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
          message,
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
            text: 'YA, LANJUTKAN',
            backgroundColor: Colors.yellowAccent,
            height: 40,
            width: 140,
            borderRadius: 4,
            onPressed: () {
              final navigator = Navigator.of(context, rootNavigator: true);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              // Wrap in microtask to avoid Navigator lock during gesture cleanup
              Future.microtask(() {
                if (navigator.canPop()) navigator.pop(); // Close dialog
                if (navigator.canPop()) navigator.pop(); // Close bottom sheet
                
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Tindakan Berhasil Diterapkan'),
                    backgroundColor: AppColors.black,
                    duration: Duration(seconds: 2),
                  ),
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            '$label ',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: isBold ? Colors.red : AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
