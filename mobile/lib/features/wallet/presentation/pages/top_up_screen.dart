import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedMethod = 'QRIS';

  final List<Map<String, String>> _paymentMethods = [
    {'name': 'BCA', 'icon': '🏦'},
    {'name': 'Mandiri', 'icon': '🏦'},
    {'name': 'QRIS', 'icon': '📱'},
    {'name': 'GoPay', 'icon': '💎'},
    {'name': 'DANA', 'icon': '💙'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF4B7BFF),
        elevation: 0,
        title: Text(
          'TOP UP SALDO',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            color: Colors.black,
            fontSize: 20,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nominal Top Up',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            BrutalistTextField(
              hintText: 'Masukkan nominal (min. Rp10.000)',
              prefixIcon: Icons.payments_rounded,
              controller: _amountController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            Text(
              'Pilih Metode Pembayaran',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _paymentMethods.map((method) {
                final isSelected = _selectedMethod == method['name'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedMethod = method['name']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.mustardYellow : Colors.white,
                      border: Border.all(color: Colors.black, width: 2.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black,
                          offset: isSelected ? const Offset(2, 2) : const Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(method['icon']!, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Text(
                          method['name']!,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 48),
            BrutalistButton(
              text: 'LANJUTKAN PEMBAYARAN',
              onPressed: () {
                // Action
              },
              backgroundColor: AppColors.neonGreen,
            ),
          ],
        ),
      ),
    );
  }
}
