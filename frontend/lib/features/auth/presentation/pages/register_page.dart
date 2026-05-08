import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/rekber_button.dart';
import '../../../../core/widgets/rekber_text_field.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Register Page — Clean sign-up form matching Kupa reference
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreeTerms = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthRegistrationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop();
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.xl),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppDimensions.lg),

                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMd,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.xl),

                    const Text('Buat Akun 🔐', style: AppTextStyles.h2),
                    const SizedBox(height: AppDimensions.xs),
                    const Text(
                      'Daftar untuk mulai bertransaksi dengan aman',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: AppDimensions.xxl),

                    // Name
                    RekberTextField(
                      label: 'Nama Lengkap',
                      hint: 'Masukkan nama lengkap',
                      controller: _nameController,
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: AppDimensions.base),

                    // Email
                    RekberTextField(
                      label: 'Email',
                      hint: 'contoh@email.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email wajib diisi';
                        if (!v.contains('@')) return 'Email tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.base),

                    // Phone
                    RekberTextField(
                      label: 'No. Handphone',
                      hint: '08xxxxxxxxxx',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'No. HP wajib diisi' : null,
                    ),
                    const SizedBox(height: AppDimensions.base),

                    // Password
                    RekberTextField(
                      label: 'Password',
                      hint: 'Minimal 6 karakter',
                      controller: _passwordController,
                      obscureText: true,
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password wajib diisi';
                        if (v.length < 6) return 'Password minimal 6 karakter';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.lg),

                    // Terms & Conditions
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreeTerms,
                            onChanged: (v) =>
                                setState(() => _agreeTerms = v ?? false),
                            activeColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.sm),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: AppTextStyles.bodySmall,
                              children: [
                                const TextSpan(text: 'Dengan mendaftar, saya menyetujui '),
                                TextSpan(
                                  text: 'Syarat & Ketentuan',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const TextSpan(text: ' dan '),
                                TextSpan(
                                  text: 'Kebijakan Privasi',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.xl),

                    // Register button
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        return RekberButton(
                          text: 'Daftar',
                          isLoading: state is AuthLoading,
                          onPressed: _agreeTerms ? _onRegister : null,
                        );
                      },
                    ),
                    const SizedBox(height: AppDimensions.xl),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Sudah punya akun? ',
                          style: AppTextStyles.bodyMedium,
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            'Masuk',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.xxl),
                  ],
                ),
              ),
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
