import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/services/api_service.dart';
import '../../../../injection_container.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Konfirmasi password baru tidak cocok.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = sl<ApiService>();
      await apiService.post('/auth/reset-password', {
        'token': _tokenController.text.trim(),
        'newPassword': _passwordController.text,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password berhasil direset! Silakan login dengan password baru.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.tealGreen,
        ),
      );

      context.go('/login');
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
          'RESET PASSWORD',
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
                    color: AppColors.tealGreen,
                    border: Border.all(color: AppColors.black, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.black,
                        offset: Offset(4, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.vpn_key_rounded,
                      size: 48, color: AppColors.black),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Buat Password Baru 🔒',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan token reset yang Anda peroleh dari email beserta password baru Anda.',
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
                      controller: _tokenController,
                      hintText: 'Token Reset Password (32 karakter)',
                      prefixIcon: Icons.key_outlined,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Token reset wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    BrutalistTextField(
                      controller: _passwordController,
                      hintText: 'Password Baru (min. 8 karakter)',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password baru wajib diisi';
                        }
                        if (v.length < 8) {
                          return 'Password minimal 8 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    BrutalistTextField(
                      controller: _confirmPasswordController,
                      hintText: 'Konfirmasi Password Baru',
                      prefixIcon: Icons.lock_clock_outlined,
                      obscureText: _obscurePassword,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Konfirmasi password wajib diisi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    BrutalistBounce(
                      onTap: _isLoading ? null : _onSubmit,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.tealGreen,
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
                                  'SIMPAN PASSWORD BARU',
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
            ],
          ),
        ),
      ),
    );
  }
}
