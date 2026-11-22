import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../cubit/transaction_cubit.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/escrow_state_machine.dart';

class InputKodeScreen extends StatefulWidget {
  const InputKodeScreen({super.key});

  @override
  State<InputKodeScreen> createState() => _InputKodeScreenState();
}

class _InputKodeScreenState extends State<InputKodeScreen> {
  final TextEditingController _kodeController = TextEditingController();
  bool _isSearching = false;
  TransactionEntity? _foundTransaction;
  String? _errorMessage;

  @override
  void dispose() {
    _kodeController.dispose();
    super.dispose();
  }

  Future<void> _searchTransaction() async {
    final code = _kodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan kode transaksi terlebih dahulu.')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _foundTransaction = null;
    });

    final tx = await context.read<TransactionCubit>().loadTransactionByCode(code);

    if (mounted) {
      setState(() {
        _isSearching = false;
        if (tx != null) {
          _foundTransaction = tx;
        } else {
          _errorMessage = 'Transaksi dengan kode "$code" tidak ditemukan.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.mustardYellow,
        elevation: 0,
        title: Text(
          'GABUNG TRANSAKSI',
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
              'Masukkan Kode Transaksi',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Minta kode unik transaksi ke lawan transaksi Anda untuk bergabung ke ruang rekber.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 16),
            BrutalistTextField(
              hintText: 'Contoh: TRX-12345',
              prefixIcon: Icons.qr_code_scanner_rounded,
              controller: _kodeController,
            ),
            const SizedBox(height: 16),
            BrutalistButton(
              text: _isSearching ? 'MENCARI...' : 'CARI TRANSAKSI',
              onPressed: _isSearching ? () {} : _searchTransaction,
              backgroundColor: Colors.black,
              textColor: Colors.white,
            ),
            const SizedBox(height: 32),

            // Error jika tidak ditemukan
            if (_errorMessage != null)
              BrutalistCard(
                backgroundColor: AppColors.paleYellow,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // Hasil Pencarian
            if (_foundTransaction != null) ...[
              Text(
                'Hasil Pencarian',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              BrutalistCard(
                backgroundColor: AppColors.paleYellow,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _foundTransaction!.description ?? 'Tanpa Deskripsi',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        BrutalistBadge(
                          text: EscrowStateMachine.getStatusLabel(_foundTransaction!.status),
                          backgroundColor: AppColors.getStatusColor(_foundTransaction!.status),
                          textColor: Colors.black,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      CurrencyFormatter.format(_foundTransaction!.amount),
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        color: AppColors.black,
                      ),
                    ),
                    const Divider(color: Colors.black, thickness: 2, height: 24),
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.black,
                          radius: 14,
                          child: Icon(Icons.person, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Penjual: ${_foundTransaction!.sellerName ?? 'Pengguna'}',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    BrutalistButton(
                      text: 'LIHAT DETAIL TRANSAKSI',
                      backgroundColor: AppColors.tealGreen,
                      textColor: Colors.black,
                      onPressed: () {
                        context.push('/transaction/${_foundTransaction!.id}');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
