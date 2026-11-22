import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../injection_container.dart';
import '../../domain/repositories/admin_repository.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class AdminKycScreen extends StatefulWidget {
  const AdminKycScreen({super.key});

  @override
  State<AdminKycScreen> createState() => _AdminKycScreenState();
}

class _AdminKycScreenState extends State<AdminKycScreen> {
  String selectedFilter = 'PENDING';

  final List<String> filters = ['PENDING', 'APPROVED', 'REJECTED', 'Semua'];

  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadKycSubmissions(status: selectedFilter);
  }

  void _onFilterChanged(String filter) {
    setState(() => selectedFilter = filter);
    context.read<AdminCubit>().loadKycSubmissions(status: filter);
  }

  void _showDocumentDetail(BuildContext context, String kycId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await sl<AdminRepository>().getKycDetail(kycId);
    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(failure.message, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.error,
          ),
        );
      },
      (data) {
        _showDetailModal(context, data);
      },
    );
  }

  void _showDetailModal(BuildContext context, Map<String, dynamic> data) {
    final fullName = data['fullName'] ?? '-';
    final nikMasked = data['nikMasked'] ?? '••••••••••••••••';
    final status = data['status'] ?? 'PENDING';
    final rejectionReason = data['rejectionReason'];
    final idFileUrl = data['idFileUrl'] as String?;
    final selfieFileUrl = data['selfieFileUrl'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: AppColors.black, width: 3),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) {
          return SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DOKUMEN KYC',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.black),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Nama Lengkap:', fullName),
                _buildInfoRow('NIK (Masked):', nikMasked),
                _buildInfoRow('Status Pengajuan:', status),
                if (rejectionReason != null)
                  _buildInfoRow('Alasan Penolakan:', rejectionReason.toString()),
                const SizedBox(height: 20),
                Text(
                  'FOTO KTP ASLI',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _buildImagePreview(idFileUrl),
                const SizedBox(height: 20),
                Text(
                  'FOTO SELFIE DENGAN KTP',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _buildImagePreview(selfieFileUrl),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildImagePreview(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: Border.all(color: AppColors.black, width: 2),
        ),
        child: const Center(
          child: Text('Tautan gambar tidak tersedia'),
        ),
      );
    }

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black12,
        border: Border.all(color: AppColors.black, width: 2),
      ),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
        ),
      ),
    );
  }

  void _showApproveConfirmation(BuildContext context, String kycId, String name) {
    final cubit = context.read<AdminCubit>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.black, width: 3),
        ),
        title: Text(
          'SETUJUI KYC',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Apakah Anda yakin menyetujui verifikasi identitas untuk "$name"? Status user akan menjadi APPROVED.',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'BATAL',
              style: GoogleFonts.spaceGrotesk(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
          BrutalistButton(
            text: 'YA, SETUJUI',
            backgroundColor: AppColors.tealGreen,
            textColor: AppColors.white,
            height: 40,
            width: 130,
            onPressed: () {
              Navigator.pop(ctx);
              cubit.approveKyc(kycId, currentFilter: selectedFilter);
            },
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, String kycId, String name) {
    final cubit = context.read<AdminCubit>();
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.black, width: 3),
        ),
        title: Text(
          'TOLAK VERIFIKASI KYC',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User: $name',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold),
                validator: (val) {
                  final text = (val ?? '').trim();
                  if (text.isEmpty) return 'Alasan penolakan wajib diisi.';
                  if (text.length < 5) return 'Alasan minimal 5 karakter.';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Contoh: Foto KTP blur/tidak terbaca jelas...',
                  hintStyle: GoogleFonts.spaceGrotesk(fontSize: 12, color: Colors.grey),
                  filled: true,
                  fillColor: AppColors.white,
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: AppColors.black, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'BATAL',
              style: GoogleFonts.spaceGrotesk(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
          BrutalistButton(
            text: 'TOLAK KYC',
            backgroundColor: Colors.redAccent,
            textColor: AppColors.white,
            height: 40,
            width: 120,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final reason = reasonController.text.trim();
                Navigator.pop(ctx);
                cubit.rejectKyc(
                      id: kycId,
                      reason: reason,
                      currentFilter: selectedFilter,
                    );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'APPROVAL KYC',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppColors.white,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── FILTER TABS ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.black, width: 2),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filters.map((f) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(f),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── KYC LIST ──
          Expanded(
            child: BlocConsumer<AdminCubit, AdminState>(
              listener: (context, state) {
                if (state is AdminActionSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.tealGreen,
                    ),
                  );
                } else if (state is AdminError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is AdminLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        BrutalSkeleton(width: double.infinity, height: 120),
                        SizedBox(height: 16),
                        BrutalSkeleton(width: double.infinity, height: 120),
                      ],
                    ),
                  );
                }

                final kycLoaded = state is AdminKycLoaded ? state : null;
                final items = kycLoaded?.submissions ?? [];

                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        context.read<AdminCubit>().loadKycSubmissions(status: selectedFilter),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_user_outlined, size: 56, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                'Antrian KYC Kosong',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tidak ada pengajuan verifikasi dalam status ini.',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      context.read<AdminCubit>().loadKycSubmissions(status: selectedFilter),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _buildKycCard(context, items[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = selectedFilter == label;
    final display = label == 'PENDING'
        ? 'MENUNGGU'
        : label == 'APPROVED'
            ? 'DISETUJUI'
            : label == 'REJECTED'
                ? 'DITOLAK'
                : 'SEMUA';

    return BrutalistBounce(
      onTap: () => _onFilterChanged(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellowAccent : AppColors.white,
          border: Border.all(color: AppColors.black, width: 2),
          boxShadow: isSelected
              ? null
              : const [
                  BoxShadow(
                    color: AppColors.black,
                    offset: Offset(2, 2),
                  ),
                ],
        ),
        child: Text(
          display,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildKycCard(BuildContext context, Map<String, dynamic> item) {
    final kycId = item['id'] as String;
    final fullName = item['fullName']?.toString() ?? '-';
    final status = item['status']?.toString() ?? 'PENDING';
    final user = item['user'] as Map<String, dynamic>?;
    final email = user?['email']?.toString() ?? '-';
    final isPending = status == 'PENDING';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: BrutalistCard(
        backgroundColor: AppColors.white,
        padding: const EdgeInsets.all(16),
        borderRadius: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    border: Border.all(color: AppColors.black, width: 2),
                  ),
                  child: const Icon(Icons.person, color: AppColors.black),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        email,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                BrutalistBadge(
                  text: status,
                  backgroundColor: status == 'APPROVED'
                      ? AppColors.tealGreen
                      : status == 'REJECTED'
                          ? Colors.redAccent
                          : Colors.orangeAccent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: BrutalistButton(
                    text: 'LIHAT DOKUMEN',
                    backgroundColor: AppColors.paleYellow,
                    height: 38,
                    borderRadius: 4,
                    icon: Icons.description_outlined,
                    onPressed: () => _showDocumentDetail(context, kycId),
                  ),
                ),
                if (isPending) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: BrutalistButton(
                      text: 'SETUJUI',
                      backgroundColor: AppColors.tealGreen,
                      textColor: AppColors.white,
                      height: 38,
                      borderRadius: 4,
                      onPressed: () => _showApproveConfirmation(context, kycId, fullName),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BrutalistButton(
                      text: 'TOLAK',
                      backgroundColor: Colors.redAccent,
                      textColor: AppColors.white,
                      height: 38,
                      borderRadius: 4,
                      onPressed: () => _showRejectDialog(context, kycId, fullName),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
