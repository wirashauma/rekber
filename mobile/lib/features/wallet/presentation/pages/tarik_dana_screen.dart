import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../injection_container.dart';
import '../../../../core/services/api_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/data/models/user_model.dart';

class TarikDanaScreen extends StatefulWidget {
  const TarikDanaScreen({super.key});

  @override
  State<TarikDanaScreen> createState() => _TarikDanaScreenState();
}

class _TarikDanaScreenState extends State<TarikDanaScreen> {
  final TextEditingController _amountController = TextEditingController();
  final String _selectedAccount = 'BCA - 12345678 a.n. Rizky';
  bool isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _withdraw() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal wajib diisi.')),
      );
      return;
    }

    final nominal = double.tryParse(amountText) ?? 0;
    if (nominal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal penarikan tidak valid.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final apiService = sl<ApiService>();
      await apiService.post('/wallet/withdraw', {
        'amount': nominal,
      });

      _showSuccessDialog();
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses penarikan: ${e.message}', style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan koneksi.', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
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
                'PENARIKAN BERHASIL!',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Permintaan penarikan dana berhasil diproses.',
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
                onPressed: () {
                  context.read<AuthBloc>().add(AuthCheckRequested());
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final balance = user is UserModel ? user.balance : 0.0;

        return Scaffold(
          backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.tealGreen,
        elevation: 0,
        title: Text(
          'TARIK DANA (WITHDRAW)',
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
            BrutalistCard(
              backgroundColor: AppColors.deepPurple,
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo Aktif',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(balance.toInt()),
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Nominal Penarikan',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            BrutalistTextField(
              hintText: 'Masukkan nominal penarikan',
              prefixIcon: Icons.outbox_rounded,
              controller: _amountController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            Text(
              'Rekening Tujuan',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                // Show bottom sheet or dialog to pick account
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 2.0),
                  boxShadow: const [
                    BoxShadow(color: Colors.black, offset: Offset(4, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_rounded, color: Colors.black),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedAccount,
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            BrutalistButton(
              text: 'TARIK SEKARANG',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? () {} : _withdraw,
              backgroundColor: Colors.black,
              textColor: Colors.white,
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Estimasi proses: 1x24 jam kerja',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}
