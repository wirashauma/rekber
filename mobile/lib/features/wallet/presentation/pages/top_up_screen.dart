import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../cubit/wallet_cubit.dart';
import '../cubit/wallet_state.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedMethod = 'QRIS'; // QRIS, VIRTUAL_ACCOUNT
  String _selectedBank = 'BCA';

  final List<int> _quickNominals = [50000, 100000, 200000, 500000];

  final List<Map<String, String>> _vaBanks = [
    {'code': 'BCA', 'name': 'BCA Virtual Account'},
    {'code': 'MANDIRI', 'name': 'Mandiri Virtual Account'},
    {'code': 'BRI', 'name': 'BRI Virtual Account'},
    {'code': 'BNI', 'name': 'BNI Virtual Account'},
    {'code': 'PERMATA', 'name': 'Permata Virtual Account'},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitTopUp() async {
    final amount = int.tryParse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount < 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal top up minimal Rp 10.000.')),
      );
      return;
    }

    final intent = await context.read<WalletCubit>().createTopUp(
          amount: amount,
          method: _selectedMethod,
          bankCode: _selectedMethod == 'VIRTUAL_ACCOUNT' ? _selectedBank : null,
        );

    if (intent != null && mounted) {
      context.push('/detail-pembayaran', extra: intent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletCubit, WalletState>(
      listener: (context, state) {
        if (state is WalletActionFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal: ${state.message}', style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is WalletActionLoading;

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
            shape: const Border(bottom: BorderSide(color: Colors.black, width: 2.0)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nominal Top Up (Rp)',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 12),
                BrutalistTextField(
                  hintText: 'Contoh: 100000 (min. Rp10.000)',
                  prefixIcon: Icons.payments_rounded,
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: _quickNominals.map((nom) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: BrutalistButton(
                          text: '${nom ~/ 1000}rb',
                          onPressed: () => setState(() => _amountController.text = nom.toString()),
                          backgroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                Text(
                  'Metode Pembayaran',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 16),

                // Option: QRIS
                GestureDetector(
                  onTap: () => setState(() => _selectedMethod = 'QRIS'),
                  child: BrutalistCard(
                    backgroundColor: _selectedMethod == 'QRIS' ? AppColors.paleYellow : Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_2_rounded, size: 36, color: Colors.black),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QRIS (Semua Bank & E-Wallet)',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'BCA, Mandiri, GoPay, OVO, DANA, ShopeePay',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedMethod == 'QRIS')
                          const Icon(Icons.check_circle_rounded, color: Colors.black),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Option: Virtual Account
                GestureDetector(
                  onTap: () => setState(() => _selectedMethod = 'VIRTUAL_ACCOUNT'),
                  child: BrutalistCard(
                    backgroundColor: _selectedMethod == 'VIRTUAL_ACCOUNT' ? AppColors.paleYellow : Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_rounded, size: 36, color: Colors.black),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Transfer Virtual Account',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Konfirmasi otomatis 24 jam',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedMethod == 'VIRTUAL_ACCOUNT')
                              const Icon(Icons.check_circle_rounded, color: Colors.black),
                          ],
                        ),
                        if (_selectedMethod == 'VIRTUAL_ACCOUNT') ...[
                          const Divider(height: 24, thickness: 1.5, color: Colors.black),
                          const Text(
                            'Pilih Bank Tujuan:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          ..._vaBanks.map((bank) {
                            return RadioListTile<String>(
                              title: Text(bank['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              value: bank['code']!,
                              groupValue: _selectedBank,
                              activeColor: Colors.black,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedBank = val);
                              },
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                BrutalistButton(
                  text: isLoading ? 'MEMPROSES...' : 'LANJUTKAN PEMBAYARAN',
                  onPressed: isLoading ? () {} : _submitTopUp,
                  backgroundColor: AppColors.tealGreen,
                  textColor: Colors.black,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
