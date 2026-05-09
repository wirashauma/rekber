import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Login Page — Neo-Brutalism (Saweria Style)
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
      backgroundColor: AppColors.primary, // Yellow Background
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.go('/home');
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
                // Logo & Title
                const Center(
                  child: BrutalistCard(
                    backgroundColor: AppColors.white,
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.shield_rounded, size: 64, color: AppColors.secondary),
                        SizedBox(height: 8),
                        Text('REKBER', style: AppTextStyles.h1),
                        Text('Escrow Platform', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),

                const Text('Halo Streamer! 👋', style: AppTextStyles.h2),
                const SizedBox(height: 8),
                const Text('Masuk untuk mulai bertransaksi aman.', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 32),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          hintText: 'Email Anda',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) => v?.contains('@') ?? false ? null : 'Email tidak valid',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) => (v?.length ?? 0) >= 6 ? null : 'Minimal 6 karakter',
                      ),
                      const SizedBox(height: 32),
                      
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          return BrutalistButton(
                            text: 'MASUK SEKARANG',
                            backgroundColor: AppColors.secondary,
                            textColor: AppColors.white,
                            isLoading: state is AuthLoading,
                            onPressed: _onLogin,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 64),
                
                // Quick Login Bypass
                Center(
                  child: Column(
                    children: [
                      const Text('Malas Login?', style: AppTextStyles.bodySmall),
                      TextButton(
                        onPressed: () {
                          // Bypass directly to home (Mock data handles the rest)
                          context.go('/home');
                        },
                        child: Text(
                          'Coba Quick Login ⚡',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.secondary,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w900,
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
