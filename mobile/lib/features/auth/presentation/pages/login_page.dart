import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            if (state.user.isAdmin) {
              context.go('/admin/dashboard');
            } else {
              context.go('/home');
            }
          }
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
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
                    child: const Icon(Icons.shield_rounded, size: 48, color: AppColors.black),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'REKBER AMAN',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Halo Gan! 👋',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masuk untuk transaksi tanpa was-was.',
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
                        hintText: 'Masukkan Email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email wajib diisi';
                          if (!v.contains('@')) return 'Email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      BrutalistTextField(
                        controller: _passwordController,
                        hintText: 'Masukkan Password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password wajib diisi';
                          if (v.length < 6) return 'Minimal 6 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          return BrutalistBounce(
                            onTap: _onLogin,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.tealGreen,
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
                                child: state is AuthLoading
                                    ? const CircularProgressIndicator(color: AppColors.black)
                                    : Text(
                                        'MASUK SEKARANG',
                                        style: GoogleFonts.spaceGrotesk(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.black, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'ATAU MASUK DENGAN',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppColors.black, thickness: 1)),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSocialButton(
                  icon: Icons.g_mobiledata_rounded,
                  label: 'Lanjutkan dengan Google',
                  color: Colors.white,
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                _buildSocialButton(
                  icon: Icons.facebook_rounded,
                  label: 'Lanjutkan dengan Facebook',
                  color: const Color(0xFF1877F2),
                  textColor: Colors.white,
                  onTap: () {},
                ),
                const SizedBox(height: 40),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/register'),
                    child: RichText(
                      text: TextSpan(
                        text: 'Belum punya akun? ',
                        style: GoogleFonts.spaceGrotesk(color: Colors.grey[700], fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Daftar di sini',
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
                const SizedBox(height: 24),
                // Quick Login Buttons (Developer Tool)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildQuickLoginButton(
                      label: 'USER TEST',
                      color: AppColors.paleYellow,
                      onTap: () {
                        _emailController.text = 'test@rekber.com';
                        _passwordController.text = 'password123';
                        _onLogin();
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildQuickLoginButton(
                      label: 'ADMIN TEST',
                      color: AppColors.lightBlue,
                      onTap: () {
                        _emailController.text = 'admin@rekber.com';
                        _passwordController.text = 'admin123';
                        _onLogin();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLoginButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return BrutalistBounce(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: AppColors.black, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: AppColors.black,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    Color textColor = AppColors.black,
    required VoidCallback onTap,
  }) {
    return BrutalistBounce(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.black, width: 2.0),
          boxShadow: const [
            BoxShadow(
              color: AppColors.black,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(AuthLoginRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ));
    }
  }
}

