import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthRegistrationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
              ),
            );
            context.go('/login');
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
                BrutalistBounce(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
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
                    child: const Icon(Icons.arrow_back, color: AppColors.black),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Buat Akun Baru 🚀',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Daftar untuk mulai bertransaksi aman.',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 40),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      BrutalistTextField(
                        controller: _nameController,
                        hintText: 'Nama Lengkap',
                        prefixIcon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Nama wajib diisi.';
                          if (value.length < 2) return 'Nama minimal 2 karakter.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      BrutalistTextField(
                        controller: _emailController,
                        hintText: 'Masukkan Email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Email wajib diisi.';
                          final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailRegex.hasMatch(value)) return 'Format email tidak valid.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      BrutalistTextField(
                        controller: _phoneController,
                        hintText: 'Nomor WhatsApp',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Nomor HP wajib diisi.';
                          if (value.length < 10) return 'Nomor HP tidak valid.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      BrutalistTextField(
                        controller: _passwordController,
                        hintText: 'Masukkan Password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Password wajib diisi.';
                          if (value.length < 8) return 'Password minimal 8 karakter.';
                          if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Harus ada huruf besar.';
                          if (!RegExp(r'[a-z]').hasMatch(value)) return 'Harus ada huruf kecil.';
                          if (!RegExp(r'[0-9]').hasMatch(value)) return 'Harus ada angka.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          return BrutalistBounce(
                            onTap: _onRegister,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: AppColors.deepPurple,
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
                                    ? const CircularProgressIndicator(color: AppColors.white)
                                    : Text(
                                        'DAFTAR SEKARANG',
                                        style: GoogleFonts.spaceGrotesk(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: AppColors.white,
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
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: RichText(
                      text: TextSpan(
                        text: 'Sudah punya akun? ',
                        style: GoogleFonts.spaceGrotesk(color: Colors.grey[700], fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Masuk di sini',
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onRegister() {
    if (_formKey.currentState?.validate() ?? false) {
      context.read<AuthBloc>().add(AuthRegisterRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          ));
    }
  }
}

