import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/services/api_service.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isChangingPassword = false;
  bool _isLoggingOutAll = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konfirmasi password tidak cocok.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isChangingPassword = true);
    try {
      final apiService = sl<ApiService>();
      await apiService.put('/auth/password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password berhasil diubah. Sesi perangkat lain telah dicabut.'),
          backgroundColor: AppColors.tealGreen,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan koneksi saat mengganti password.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  void _confirmLogoutAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.black, width: 3),
        ),
        title: Text(
          'KELUAR SEMUA PERANGKAT',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari semua perangkat? Seluruh sesi login Anda akan dihentikan dan Anda harus login kembali.',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'BATAL',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          BrutalistButton(
            text: 'YA, KELUAR SEMUA',
            backgroundColor: AppColors.error,
            textColor: AppColors.white,
            height: 42,
            width: 170,
            onPressed: () {
              Navigator.pop(ctx);
              _logoutAll();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _logoutAll() async {
    setState(() => _isLoggingOutAll = true);
    try {
      final apiService = sl<ApiService>();
      await apiService.post('/auth/logout-all', {});
    } catch (_) {
      // Even if server fails, clear local tokens & logout
    }

    if (!mounted) return;
    context.read<AuthBloc>().add(AuthLogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'KEAMANAN AKUN',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.0),
          child: Container(
            color: AppColors.black,
            height: 2.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GANTI PASSWORD',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mengubah password akan secara otomatis mencabut sesi login pada perangkat lain.',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              _buildLabel('Password Saat Ini'),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                validator: (val) =>
                    (val == null || val.isEmpty) ? 'Password saat ini wajib diisi' : null,
                decoration: InputDecoration(
                  hintText: 'Masukkan password saat ini',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.black),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.black,
                    ),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.black, width: 2.5),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.black, width: 2.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel('Password Baru'),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Password baru wajib diisi';
                  if (val.length < 8) return 'Password minimal 8 karakter';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Minimal 8 karakter',
                  prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.black),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.black,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.black, width: 2.5),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.black, width: 2.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel('Konfirmasi Password Baru'),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Konfirmasi password wajib diisi';
                  if (val != _newPasswordController.text) return 'Password tidak cocok';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Ulangi password baru',
                  prefixIcon: const Icon(Icons.verified_user_outlined, color: AppColors.black),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.black,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.black, width: 2.5),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.black, width: 2.5),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              BrutalistButton(
                text: 'SIMPAN PASSWORD BARU',
                isLoading: _isChangingPassword,
                onPressed: _isChangingPassword ? () {} : _changePassword,
                backgroundColor: AppColors.hotPink,
                textColor: AppColors.white,
              ),

              const SizedBox(height: 48),
              const Divider(color: AppColors.black, thickness: 2),
              const SizedBox(height: 32),

              Text(
                'SESI & PERANGKAT',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cabut semua sesi login aktif di peramban dan perangkat seluler lainnya.',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),

              BrutalistButton(
                text: 'KELUAR DARI SEMUA PERANGKAT',
                isLoading: _isLoggingOutAll,
                onPressed: _isLoggingOutAll ? () {} : _confirmLogoutAll,
                backgroundColor: AppColors.black,
                textColor: AppColors.white,
                icon: Icons.power_settings_new_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          color: AppColors.black,
        ),
      ),
    );
  }
}
