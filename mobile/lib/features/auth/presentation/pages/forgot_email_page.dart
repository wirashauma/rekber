import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/services/api_service.dart';
import '../../../../injection_container.dart';

class ForgotEmailPage extends StatefulWidget {
  const ForgotEmailPage({super.key});

  @override
  State<ForgotEmailPage> createState() => _ForgotEmailPageState();
}

class _ForgotEmailPageState extends State<ForgotEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _recoveredEmail;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _recoveredEmail = null;
    });

    try {
      final apiService = sl<ApiService>();
      final response = await apiService.post('/auth/forgot-email', {
        'name': _nameController.text.trim(),
        'password': _passwordController.text,
      });

      setState(() {
        _recoveredEmail = response['data']['email'];
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan koneksi. Silakan coba lagi.';
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
              child: const Icon(Icons.arrow_back, color: AppColors.black, size: 20),
            ),
          ),
        ),
        title: Text(
          'LUPA EMAIL',
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
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
                  child: const Icon(Icons.contact_support_rounded, size: 48, color: AppColors.black),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Lupa Email Anda? 🤔',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Jangan panik Gan. Masukkan Nama Lengkap dan Password Anda untuk memulihkan email terdaftar Anda.',
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
                      controller: _nameController,
                      hintText: 'Nama Lengkap (sesuai registrasi)',
                      prefixIcon: Icons.person_outline,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Nama Lengkap wajib diisi';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    BrutalistTextField(
                      controller: _passwordController,
                      hintText: 'Password Akun Anda',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password wajib diisi';
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
                          color: AppColors.mustardYellow,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.black, width: 2.5),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.black,
                              offset: Offset(4, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: _isLoading
                              ? const CircularProgressIndicator(color: AppColors.black)
                              : Text(
                                  'CARI EMAIL SAYA',
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
              const SizedBox(height: 32),
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
              if (_recoveredEmail != null)
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
                        'Email Berhasil Ditemukan! 🎉',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          border: Border.all(color: AppColors.black, width: 1.5),
                        ),
                        child: SelectableText(
                          _recoveredEmail!,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepPurple,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      BrutalistBounce(
                        onTap: () => context.pop(_recoveredEmail),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            border: Border.all(color: AppColors.black, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.black,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'GUNAKAN UNTUK LOGIN',
                              style: GoogleFonts.spaceGrotesk(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
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
