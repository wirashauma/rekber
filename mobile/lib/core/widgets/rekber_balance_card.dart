import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class RekberBalanceCard extends StatelessWidget {
  final double principalBalance;
  final double activeBalance;
  final double guaranteeBalance;

  const RekberBalanceCard({
    super.key,
    required this.principalBalance,
    required this.activeBalance,
    required this.guaranteeBalance,
  });

  String _formatRupiah(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return formatter.format(amount).replaceAll(',', '.');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220, // Explicit height to handle overflow
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── CARD BODY ──
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF6DC4A7), // Pastel Mint Green
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(8, 8), // 3D Hard Shadow
                    blurRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Dot Pattern Overlay
                    Positioned.fill(
                      child: CustomPaint(
                        painter: DotPatternPainter(),
                      ),
                    ),
                    
                    // Balance Content (Right Side)
                    Align(
                      alignment: Alignment.centerRight,
                      child: FractionallySizedBox(
                        widthFactor: 0.65,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20.0, top: 12, bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'SALDO REKBER',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: Colors.black.withValues(alpha: 0.8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatRupiah(principalBalance),
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 40,
                                    color: Colors.black,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // White Sub-balance Container
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _subBalanceItem('Saldo Aktif', activeBalance),
                                    ),
                                    Container(
                                      width: 2,
                                      height: 24,
                                      color: Colors.black12,
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    Expanded(
                                      child: _subBalanceItem('Masa Garansi', guaranteeBalance),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // ── MASCOT (POPPING OUT) ──
          Positioned(
            left: -10,
            bottom: -15,
            child: Image.asset(
              'assets/images/maskot.png',
              height: 230,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subBalanceItem(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 9,
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _formatRupiah(value),
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12) // Slightly more visible
      ..style = PaintingStyle.fill;

    const double spacing = 10.0; // Denser pattern
    const double dotRadius = 0.8;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
