import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../cubit/transaction_cubit.dart';
import '../../data/models/public_config_model.dart';

class KalkulatorScreen extends StatefulWidget {
  const KalkulatorScreen({super.key});

  @override
  State<KalkulatorScreen> createState() => _KalkulatorScreenState();
}

class _KalkulatorScreenState extends State<KalkulatorScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _feePayer = 'Pembeli'; // Pembeli, Penjual, Dibagi Dua
  PublicConfigModel? _config;

  int get _amount =>
      int.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  int get _fee {
    if (_config != null) {
      return _config!.calculateFee(_amount);
    }
    final raw = (_amount * 0.02).ceil();
    return raw < 1000 ? 1000 : raw;
  }

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConfig();
    });
  }

  Future<void> _loadConfig() async {
    final cfg = await context.read<TransactionCubit>().loadPublicConfig();
    if (mounted) {
      setState(() => _config = cfg);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buyerFee = _feePayer == 'Pembeli'
        ? _fee
        : (_feePayer == 'Dibagi Dua' ? (_fee / 2).ceil() : 0);
    final sellerFee = _feePayer == 'Penjual'
        ? _fee
        : (_feePayer == 'Dibagi Dua' ? (_fee / 2).floor() : 0);

    final feePercentDisplay =
        _config != null ? '${(_config!.feePercent * 100).toStringAsFixed(1)}%' : '2%';
    final feeMinDisplay =
        _config != null ? CurrencyFormatter.format(_config!.feeMin) : 'Rp1.000';

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
        shape: const Border(bottom: BorderSide(color: Colors.black, width: 2.0)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nominal Transaksi (Rp)',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            BrutalistTextField(
              hintText: 'Contoh: 500000',
              prefixIcon: Icons.calculate_rounded,
              controller: _amountController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Text(
              'Tarif resmi: $feePercentDisplay (minimal $feeMinDisplay)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 28),

            Text(
              'Siapa yang menanggung Fee Platform?',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildFeeChip('Pembeli'),
                const SizedBox(width: 8),
                _buildFeeChip('Penjual'),
                const SizedBox(width: 8),
                _buildFeeChip('Dibagi Dua'),
              ],
            ),
            const SizedBox(height: 28),

            BrutalistCard(
              backgroundColor: AppColors.mustardYellow,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildResultRow('Harga Barang', CurrencyFormatter.format(_amount)),
                  const SizedBox(height: 12),
                  _buildResultRow(
                    'Fee Rekber ($feePercentDisplay)',
                    CurrencyFormatter.format(_fee),
                  ),
                  const Divider(color: Colors.black, thickness: 2, height: 32),
                  _buildResultRow(
                    'Total Pembeli Bayar',
                    CurrencyFormatter.format(_amount + buyerFee),
                    isBold: true,
                  ),
                  const SizedBox(height: 8),
                  _buildResultRow(
                    'Total Penjual Terima',
                    CurrencyFormatter.format(_amount - sellerFee),
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
            boxShadow: isSelected
                ? null
                : const [BoxShadow(color: Colors.black, offset: Offset(3, 3))],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
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

  Widget _buildResultRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }
}
