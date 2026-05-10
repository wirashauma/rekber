import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/brutal_skeleton.dart';

class KalkulatorScreen extends StatefulWidget {
  const KalkulatorScreen({super.key});

  @override
  State<KalkulatorScreen> createState() => _KalkulatorScreenState();
}

class _KalkulatorScreenState extends State<KalkulatorScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _feePayer = 'Pembeli'; // Pembeli, Penjual, Dibagi Dua
  bool isLoading = true;

  double get _amount => double.tryParse(_amountController.text) ?? 0;
  double get _fee => _amount * 0.02; // Fixed 2% fee for mock

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
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
        backgroundColor: AppColors.hotPink,
        elevation: 0,
        title: Text(
          'KALKULATOR FEE',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            color: Colors.black,
            fontSize: 18,
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
                children: List.generate(4, (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: BrutalSkeleton(width: double.infinity, height: 100),
                )),
              )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nominal Transaksi',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            BrutalistTextField(
              hintText: 'Rp 0',
              prefixIcon: Icons.calculate_rounded,
              controller: _amountController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            Text(
              'Siapa yang menanggung Fee Admin?',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildFeeChip('Pembeli'),
                const SizedBox(width: 8),
                _buildFeeChip('Penjual'),
                const SizedBox(width: 8),
                _buildFeeChip('Dibagi Dua'),
              ],
            ),
            const SizedBox(height: 32),
            BrutalistCard(
              backgroundColor: AppColors.mustardYellow,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildResultRow('Harga Barang', _amount),
                  const SizedBox(height: 12),
                  _buildResultRow('Fee Rekber (2%)', _fee),
                  const Divider(color: Colors.black, thickness: 2, height: 32),
                  _buildResultRow(
                    'Total Pembeli Bayar', 
                    _feePayer == 'Pembeli' ? _amount + _fee : (_feePayer == 'Dibagi Dua' ? _amount + (_fee/2) : _amount),
                    isBold: true,
                  ),
                  const SizedBox(height: 8),
                  _buildResultRow(
                    'Total Penjual Terima', 
                    _feePayer == 'Penjual' ? _amount - _fee : (_feePayer == 'Dibagi Dua' ? _amount - (_fee/2) : _amount),
                    isBold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeChip(String label) {
    final isSelected = _feePayer == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _feePayer = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.white,
            border: Border.all(color: Colors.black, width: 2.0),
            boxShadow: isSelected ? null : [
              const BoxShadow(color: Colors.black, offset: Offset(3, 3)),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, double value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            fontSize: isBold ? 16 : 14,
          ),
        ),
        Text(
          CurrencyFormatter.format(value.toInt()),
          style: GoogleFonts.spaceGrotesk(
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            fontSize: isBold ? 18 : 14,
          ),
        ),
      ],
    );
  }
}
