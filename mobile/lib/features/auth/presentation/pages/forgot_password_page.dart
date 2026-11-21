import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/services/api_service.dart';
import '../../../../injection_container.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _infoMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final apiService = sl<ApiService>();
      final response = await apiService.post('/auth/forgot-password', {
        'email': _emailController.text.trim(),
      });

      setState(() {
        _infoMessage = response['message'] ??
            'Jika email Anda terdaftar, instruksi reset password telah dikirim ke email Anda.';
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage =
            'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: BrutalistBounce(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.black, width: 2),
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.black, size: 20),
            ),
          ),
        ),
        title: Text(
          'LUPA PASSWORD',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: AppColors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.mustardYellow,
                    border: Border.all(color: AppColors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.black,
                        offset: Offset(4, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      size: 48, color: AppColors.black),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Lupa Password Anda? 🔑',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan alamat email terdaftar Anda. Kami akan mengirimkan instruksi dan token untuk mengatur ulang password.',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    BrutalistTextField(
                      controller: _emailController,
                      hintText: 'Masukkan Email Terdaftar',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email wajib diisi';
                        }
                        if (!v.contains('@')) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    BrutalistBounce(
                      onTap: _isLoading ? null : _onSubmit,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.mustardYellow,
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: AppColors.black, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.black,
                              offset: Offset(4, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: AppColors.black)
                              : Text(
                                  'KIRIM INSTRUKSI RESET',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.2),
                    border: Border.all(color: AppColors.error, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.black,
                        offset: Offset(3, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_infoMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withValues(alpha: 0.2),
                    border: Border.all(color: AppColors.black, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.black,
                        offset: Offset(4, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Permintaan Terkirim! ✉️',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _infoMessage!,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              Center(
                child: TextButton(
                  onPressed: () => context.push('/reset-password'),
                  child: RichText(
                    text: TextSpan(
                      text: 'Sudah punya token reset? ',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: 'Reset Password di sini',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppColors.black,
                            fontWeight: FontWeight.w900,
                            decoration: TextDecoration.underline,
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
    );
  }
}
