import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';

import '../../../../core/widgets/brutal_skeleton.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedMethod = 'QRIS';
  bool isLoading = true;

  final List<String> _quickNominals = ['50000', '100000', '500000'];

  final List<Map<String, dynamic>> _paymentCategories = [
    {
      'title': 'Transfer Bank (Virtual Account)',
      'methods': [
        {'name': 'BCA', 'icon': '🏦'},
        {'name': 'Mandiri', 'icon': '🏦'},
        {'name': 'BRI', 'icon': '🏦'},
        {'name': 'BNI', 'icon': '🏦'},
        {'name': 'Permata', 'icon': '🏦'},
      ]
    },
    {
      'title': 'E-Wallet',
      'methods': [
        {'name': 'DANA', 'icon': '💙'},
        {'name': 'OVO', 'icon': '💜'},
        {'name': 'ShopeePay', 'icon': '🧡'},
        {'name': 'LinkAja', 'icon': '❤️'},
      ]
    },
    {
      'title': 'QRIS',
      'methods': [
        {'name': 'QRIS', 'icon': '📱'},
      ]
    },
    {
      'title': 'Gerai Retail',
      'methods': [
        {'name': 'Alfamart', 'icon': '🏪'},
        {'name': 'Indomaret', 'icon': '🏪'},
      ]
    },
  ];

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
        child: isLoading 
          ? Column(
              children: List.generate(6, (index) => const Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: BrutalSkeleton(width: double.infinity, height: 80),
              )),
            )
          : Column(
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
            const SizedBox(height: 12),
            Row(
              children: _quickNominals.map((nom) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: BrutalistButton(
                    text: 'Rp${nom.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                    onPressed: () => setState(() => _amountController.text = nom),
                    backgroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              )).toList(),
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
            ..._paymentCategories.map((cat) => _buildCategory(cat)),
            const SizedBox(height: 48),
            BrutalistButton(
              text: 'LANJUTKAN PEMBAYARAN',
              onPressed: () {
                if (_amountController.text.isNotEmpty) {
                  context.push('/detail-pembayaran', extra: {
                    'nominal': _amountController.text,
                    'method': _selectedMethod,
                  });
                }
              },
              backgroundColor: AppColors.neonGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(Map<String, dynamic> category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2.0),
          boxShadow: const [
            BoxShadow(color: Colors.black, offset: Offset(4, 4)),
          ],
        ),
        child: Theme(
          data: ThemeData().copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(
              category['title'].toString().toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            iconColor: Colors.black,
            collapsedIconColor: Colors.black,
            childrenPadding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: (category['methods'] as List).map((method) {
                  final isSelected = _selectedMethod == method['name'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMethod = method['name']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.mustardYellow : Colors.white,
                        border: Border.all(color: Colors.black, width: 2.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black,
                            offset: isSelected ? const Offset(1, 1) : const Offset(3, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(method['icon'], style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Text(
                            method['name'],
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
