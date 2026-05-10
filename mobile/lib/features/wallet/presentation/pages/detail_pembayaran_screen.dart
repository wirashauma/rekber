import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/utils/currency_formatter.dart';

class DetailPembayaranScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const DetailPembayaranScreen({super.key, required this.data});

  @override
  State<DetailPembayaranScreen> createState() => _DetailPembayaranScreenState();
}

class _DetailPembayaranScreenState extends State<DetailPembayaranScreen> {
  late Timer _timer;
  int _secondsRemaining = 86399; // 23:59:59

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.tealGreen,
            border: Border.all(color: Colors.black, width: 4.0),
            boxShadow: const [
              BoxShadow(color: Colors.black, offset: Offset(8, 8)),
            ],
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 80, color: Colors.black),
              const SizedBox(height: 24),
              Text(
                'TOP UP BERHASIL!',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Dana sudah masuk ke Saldo Aktif Anda.',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 32),
              BrutalistButton(
                text: 'KEMBALI KE BERANDA',
                backgroundColor: Colors.black,
                textColor: Colors.white,
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nominal = double.tryParse(widget.data['nominal'] ?? '0') ?? 0;
    const adminFee = 4000.0;
    final total = nominal + adminFee;
    final method = widget.data['method'] ?? 'Transfer Bank';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'DETAIL PEMBAYARAN',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
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
          children: [
            // --- Receipt Card ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 3.0),
                boxShadow: const [
                  BoxShadow(color: Colors.black, offset: Offset(6, 6)),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          'BATAS WAKTU PEMBAYARAN',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDuration(_secondsRemaining),
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Dashed Line
                  CustomPaint(
                    size: const Size(double.infinity, 2),
                    painter: DashedLinePainter(),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Metode', method),
                        const SizedBox(height: 16),
                        Text(
                          'NOMOR VIRTUAL ACCOUNT',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '8077 1234 5678 9012',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            BrutalistButton(
                              text: 'SALIN',
                              onPressed: () {
                                Clipboard.setData(const ClipboardData(text: '8077123456789012'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Nomor VA disalin!')),
                                );
                              },
                              backgroundColor: AppColors.paleYellow,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Colors.black, thickness: 1),
                        const SizedBox(height: 16),
                        _buildPriceRow('Nominal Top Up', nominal),
                        const SizedBox(height: 12),
                        _buildPriceRow('Biaya Admin', adminFee),
                        const SizedBox(height: 24),
                        Text(
                          'TOTAL PEMBAYARAN',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(total.toInt()),
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 36,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            BrutalistButton(
              text: 'SAYA SUDAH BAYAR',
              onPressed: _showSuccessDialog,
              backgroundColor: AppColors.neonGreen,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          CurrencyFormatter.format(value.toInt()),
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 14),
        ),
      ],
    );
  }
}

class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    double dashWidth = 5, dashSpace = 3, startX = 0;
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
