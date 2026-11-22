import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../injection_container.dart';
import '../cubit/kyc_cubit.dart';
import '../cubit/kyc_state.dart';

class KycScreen extends StatelessWidget {
  const KycScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<KycCubit>()..fetchKycStatus(),
      child: const _KycScreenView(),
    );
  }
}

class _KycScreenView extends StatefulWidget {
  const _KycScreenView();

  @override
  State<_KycScreenView> createState() => _KycScreenViewState();
}

class _KycScreenViewState extends State<_KycScreenView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nikController = TextEditingController();
  final _picker = ImagePicker();

  File? _ktpFile;
  File? _selfieFile;

  @override
  void dispose() {
    _nameController.dispose();
    _nikController.dispose();
    super.dispose();
  }

  Future<void> _pickAndCropImage({
    required bool isKtp,
    required ImageSource source,
  }) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      CroppedFile? croppedFile;
      try {
        croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: isKtp ? 'Sesuaikan Foto KTP' : 'Sesuaikan Foto Selfie',
              toolbarColor: AppColors.black,
              toolbarWidgetColor: AppColors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: isKtp ? 'Sesuaikan Foto KTP' : 'Sesuaikan Foto Selfie',
            ),
          ],
        );
      } catch (_) {
        // Fallback to original file if cropper is not available/fails
        croppedFile = null;
      }

      final resultFile = File(croppedFile?.path ?? pickedFile.path);
      setState(() {
        if (isKtp) {
          _ktpFile = resultFile;
        } else {
          _selfieFile = resultFile;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil gambar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog({required bool isKtp}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.black, width: 3),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isKtp ? 'PILIH FOTO KTP' : 'PILIH FOTO SELFIE',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.black),
                title: Text(
                  'Kamera',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndCropImage(isKtp: isKtp, source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.black),
                title: Text(
                  'Galeri Foto',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndCropImage(isKtp: isKtp, source: ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_ktpFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto KTP wajib diunggah.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selfieFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto selfie dengan KTP wajib diunggah.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    context.read<KycCubit>().submitKyc(
          fullName: _nameController.text.trim(),
          nik: _nikController.text.trim(),
          idCardFile: _ktpFile!,
          selfieFile: _selfieFile!,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'VERIFIKASI IDENTITAS',
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
      body: BlocConsumer<KycCubit, KycState>(
        listener: (context, state) {
          if (state is KycFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.error,
              ),
            );
          } else if (state is KycSubmitSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.tealGreen,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is KycLoading) {
            return _buildLoadingSkeleton();
          }

          final kycLoaded = state is KycLoaded ? state : null;
          final status = kycLoaded?.status ?? 'NONE';
          final rejectionReason = kycLoaded?.rejectionReason;
          final isPending = status == 'PENDING';
          final isApproved = status == 'APPROVED';
          final isRejected = status == 'REJECTED';
          final isSubmitting = state is KycSubmitting;

          return RefreshIndicator(
            onRefresh: () => context.read<KycCubit>().fetchKycStatus(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Banner
                    _buildStatusBanner(
                      status: status,
                      rejectionReason: rejectionReason,
                      nikMasked: kycLoaded?.nikMasked,
                    ),
                    const SizedBox(height: 28),

                    if (isPending) ...[
                      _buildPendingInfoCard(),
                    ] else if (isApproved) ...[
                      _buildApprovedInfoCard(kycLoaded),
                    ] else ...[
                      // Allow submit when NONE or REJECTED
                      if (isRejected)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Silakan perbaiki data & unggah ulang foto yang jelas.',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      _buildLabel('Nama Lengkap (Sesuai KTP)'),
                      BrutalistTextField(
                        controller: _nameController,
                        hintText: 'Masukkan nama lengkap',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 20),

                      _buildLabel('NIK (Nomor Induk Kependudukan)'),
                      TextFormField(
                        controller: _nikController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(16),
                        ],
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                        validator: (value) {
                          final clean = (value ?? '').trim();
                          if (clean.isEmpty) return 'NIK wajib diisi.';
                          if (clean.length != 16) return 'NIK harus terdiri dari tepat 16 digit.';
                          return null;
                        },
                        decoration: const InputDecoration(
                          hintText: '16 digit angka',
                          prefixIcon: Icon(Icons.credit_card_rounded, color: AppColors.black),
                          filled: true,
                          fillColor: AppColors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: AppColors.black, width: 2.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: AppColors.black, width: 2.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: AppColors.brightBlue, width: 3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      Text(
                        'DOKUMEN IDENTITAS',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildUploadBox(
                        title: 'Foto e-KTP Asli',
                        subtitle: 'Pastikan seluruh sisi dan tulisan terbaca jelas',
                        icon: Icons.badge_outlined,
                        file: _ktpFile,
                        onTap: () => _showImageSourceDialog(isKtp: true),
                      ),
                      const SizedBox(height: 20),

                      _buildUploadBox(
                        title: 'Foto Selfie Memegang e-KTP',
                        subtitle: 'Wajah dan identitas e-KTP harus terlihat terang & fokus',
                        icon: Icons.camera_front_outlined,
                        file: _selfieFile,
                        onTap: () => _showImageSourceDialog(isKtp: false),
                      ),
                      const SizedBox(height: 36),

                      if (isSubmitting)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.paleYellow,
                            border: Border.all(color: AppColors.black, width: 2),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  state.step,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        BrutalistButton(
                          text: isRejected ? 'KIRIM ULANG DOKUMEN' : 'KIRIM DOKUMEN',
                          onPressed: _submit,
                          backgroundColor: AppColors.brightBlue,
                          textColor: AppColors.white,
                        ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Data Anda dienkripsi secara aman dengan AES-256.',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner({
    required String status,
    String? rejectionReason,
    String? nikMasked,
  }) {
    Color bg;
    IconData icon;
    String title;
    String desc;

    switch (status) {
      case 'APPROVED':
        bg = AppColors.tealGreen;
        icon = Icons.verified_rounded;
        title = 'TERVERIFIKASI (APPROVED)';
        desc = 'Identitas Anda telah terverifikasi. Seluruh fitur penarikan aktif.';
        break;
      case 'PENDING':
        bg = AppColors.mustardYellow;
        icon = Icons.hourglass_top_rounded;
        title = 'SEDANG DITINJAU';
        desc = 'Dokumen KYC Anda sedang diperiksa oleh tim verifikasi admin.';
        break;
      case 'REJECTED':
        bg = Colors.redAccent;
        icon = Icons.cancel_outlined;
        title = 'VERIFIKASI DITOLAK';
        desc = rejectionReason ?? 'Dokumen tidak memenuhi persyaratan. Silakan ajukan ulang.';
        break;
      default:
        bg = AppColors.paleYellow;
        icon = Icons.info_outline_rounded;
        title = 'BELUM VERIFIKASI';
        desc = 'Verifikasi e-KTP untuk meningkatkan keamanan dan mengaktifkan penarikan saldo.';
        break;
    }

    return BrutalistCard(
      backgroundColor: bg,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.black, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.black,
                  ),
                ),
                if (nikMasked != null && nikMasked.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'NIK: $nikMasked',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.black, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.black,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.access_time_filled_rounded, size: 48, color: AppColors.black),
          const SizedBox(height: 12),
          Text(
            'Pengajuan Dalam Antrian',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Proses peninjauan biasanya memakan waktu maksimal 1x24 jam kerja. Anda akan menerima notifikasi saat proses selesai.',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedInfoCard(KycLoaded? kyc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.black, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.black,
            offset: Offset(4, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, size: 52, color: AppColors.tealGreen),
          const SizedBox(height: 12),
          Text(
            kyc?.fullName ?? 'Akun Terverifikasi',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'NIK: ${kyc?.nikMasked ?? "••••••••••••••••"}',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Selamat! Anda memiliki akses penuh ke seluruh transaksi escrow dan penarikan saldo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBox({
    required String title,
    required String subtitle,
    required IconData icon,
    required File? file,
    required VoidCallback onTap,
  }) {
    final hasFile = file != null;

    return BrutalistBounce(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: hasFile ? AppColors.tealGreen.withValues(alpha: 0.15) : AppColors.white,
          border: Border.all(
            color: hasFile ? AppColors.tealGreen : AppColors.black,
            width: 2.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.black,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              hasFile ? Icons.check_circle_outline_rounded : icon,
              size: 44,
              color: hasFile ? AppColors.tealGreen : AppColors.black,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasFile ? 'Berkas siap diunggah' : subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: hasFile ? AppColors.tealGreen : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: hasFile ? AppColors.tealGreen : AppColors.paleYellow,
                border: Border.all(color: AppColors.black, width: 1.5),
              ),
              child: Text(
                hasFile ? 'GANTI FOTO' : 'PILIH FOTO',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: hasFile ? AppColors.white : AppColors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 2),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: AppColors.black,
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          BrutalSkeleton(width: double.infinity, height: 80),
          SizedBox(height: 24),
          BrutalSkeleton(width: double.infinity, height: 50),
          SizedBox(height: 16),
          BrutalSkeleton(width: double.infinity, height: 50),
          SizedBox(height: 24),
          BrutalSkeleton(width: double.infinity, height: 160),
          SizedBox(height: 20),
          BrutalSkeleton(width: double.infinity, height: 160),
        ],
      ),
    );
  }
}
