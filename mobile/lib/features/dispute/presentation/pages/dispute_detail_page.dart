import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/dispute_entity.dart';
import '../cubit/dispute_cubit.dart';
import '../cubit/dispute_state.dart';

class DisputeDetailPage extends StatefulWidget {
  final String disputeId;

  const DisputeDetailPage({super.key, required this.disputeId});

  @override
  State<DisputeDetailPage> createState() => _DisputeDetailPageState();
}

class _DisputeDetailPageState extends State<DisputeDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DisputeCubit>().loadDispute(widget.disputeId);
    });
  }

  void _showAddEvidenceModal(DisputeEntity dispute) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEvidenceModal(
        disputeId: dispute.id,
        onSuccess: () {
          context.read<DisputeCubit>().loadDispute(widget.disputeId);
        },
      ),
    );
  }

  void _openImageViewer(String fileIdOrUrl) async {
    String displayUrl = fileIdOrUrl;
    if (!fileIdOrUrl.startsWith('http')) {
      try {
        final api = sl<ApiService>();
        final res = await api.get('/files/$fileIdOrUrl/url');
        if (res != null && res['data']?['url'] != null) {
          displayUrl = res['data']['url'];
        }
      } catch (_) {}
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black.withValues(alpha: 0.95),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.network(
                  displayUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Text(
                      'Gagal memuat gambar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.black, size: 28),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'DETAIL SENGKETA',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(
            color: AppColors.black,
            height: 4.0,
          ),
        ),
      ),
      body: BlocConsumer<DisputeCubit, DisputeState>(
        listener: (context, state) {
          if (state is DisputeError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.error,
              ),
            );
          } else if (state is DisputeActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is DisputeLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.black));
          }

          final dispute = state is DisputeLoaded
              ? state.dispute
              : context.read<DisputeCubit>().currentDispute;

          if (dispute == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    const Text('Data sengketa tidak ditemukan.', style: AppTextStyles.h3),
                    const SizedBox(height: 16),
                    BrutalistButton(
                      text: 'KEMBALI',
                      backgroundColor: AppColors.black,
                      textColor: AppColors.white,
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
              ),
            );
          }

          final canAddEvidence = dispute.status == 'OPEN' || dispute.status == 'UNDER_REVIEW';

          return RefreshIndicator(
            onRefresh: () => context.read<DisputeCubit>().loadDispute(widget.disputeId),
            color: AppColors.black,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner
                  _buildStatusBanner(dispute),
                  const SizedBox(height: 20),

                  // Detail Dispute Card
                  _buildDisputeInfoCard(dispute),
                  const SizedBox(height: 20),

                  // Admin Decision Card (if resolved)
                  if (dispute.status.startsWith('RESOLVED')) ...[
                    _buildResolutionCard(dispute),
                    const SizedBox(height: 20),
                  ],

                  // Evidences List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BUKTI TERLAMPIR (${dispute.evidences.length})',
                        style: AppTextStyles.h3.copyWith(fontSize: 16),
                      ),
                      if (canAddEvidence)
                        ElevatedButton.icon(
                          onPressed: () => _showAddEvidenceModal(dispute),
                          icon: const Icon(Icons.add, size: 18, color: Colors.black),
                          label: const Text('Tambah Bukti', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            elevation: 0,
                            side: const BorderSide(color: AppColors.black, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (dispute.evidences.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        border: Border.all(color: AppColors.black, width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          'Belum ada bukti tambahan yang diunggah.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ...dispute.evidences.map((ev) => _buildEvidenceItem(ev)),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(DisputeEntity dispute) {
    Color bg;
    String label;
    IconData icon;

    switch (dispute.status) {
      case 'OPEN':
        bg = AppColors.paleYellow;
        label = 'SENGKETA DIAJUKAN (MENUNGGU RESPON)';
        icon = Icons.info_outline_rounded;
        break;
      case 'UNDER_REVIEW':
        bg = AppColors.lightBlue;
        label = 'SEDANG DITINJAU ADMIN';
        icon = Icons.hourglass_top_rounded;
        break;
      case 'RESOLVED_BUYER':
        bg = AppColors.success;
        label = 'SELESAI — DANA DIKEMBALIKAN KE PEMBELI';
        icon = Icons.check_circle_rounded;
        break;
      case 'RESOLVED_SELLER':
        bg = AppColors.tealGreen;
        label = 'SELESAI — DANA DITERUSKAN KE PENJUAL';
        icon = Icons.check_circle_rounded;
        break;
      default:
        bg = AppColors.mustardYellow;
        label = dispute.status;
        icon = Icons.help_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: AppColors.black, width: 2.5),
        boxShadow: const [BoxShadow(color: AppColors.black, offset: Offset(4, 4))],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.black, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisputeInfoCard(DisputeEntity dispute) {
    return BrutalistCard(
      backgroundColor: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Alasan Sengketa', style: AppTextStyles.labelMedium),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.error, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _translateReason(dispute.reason),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Deskripsi Pengaduan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            dispute.description,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'Diajukan pada: ${_formatDateTime(dispute.createdAt)}',
            style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionCard(DisputeEntity dispute) {
    return BrutalistCard(
      backgroundColor: const Color(0xFFE8F5E9),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gavel_rounded, color: AppColors.black, size: 22),
              SizedBox(width: 8),
              Text(
                'KEPUTUSAN RESOLUSI ADMIN',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            dispute.resolutionNote ?? 'Sengketa telah diputuskan sesuai ketentuan layanan escrow.',
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, height: 1.4),
          ),
          if (dispute.resolvedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Tanggal Keputusan: ${_formatDateTime(dispute.resolvedAt!)}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenceItem(DisputeEvidenceEntity ev) {
    final authState = context.watch<AuthBloc>().state;
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : '';
    final isMe = ev.submittedById == currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: BrutalistCard(
        backgroundColor: isMe ? const Color(0xFFF1F8E9) : AppColors.white,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isMe ? 'Bukti dari Anda' : 'Bukti dari Pihak Lawan',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: isMe ? AppColors.tealGreen : AppColors.black,
                  ),
                ),
                Text(
                  _formatDateTime(ev.createdAt),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
            if (ev.note != null && ev.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ev.note!,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            if (ev.fileIds.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ev.fileIds.map((fileId) {
                  return GestureDetector(
                    onTap: () => _openImageViewer(fileId),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.black, width: 2),
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey.shade200,
                      ),
                      child: const Center(
                        child: Icon(Icons.zoom_in_rounded, color: AppColors.black, size: 28),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _translateReason(String reason) {
    switch (reason) {
      case 'NOT_RECEIVED':
        return 'Barang Tidak Diterima';
      case 'NOT_AS_DESCRIBED':
        return 'Tidak Sesuai Deskripsi';
      case 'DEFECTIVE':
        return 'Barang Cacat/Rusak';
      case 'OTHER':
        return 'Lainnya';
      default:
        return reason;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _AddEvidenceModal extends StatefulWidget {
  final String disputeId;
  final VoidCallback onSuccess;

  const _AddEvidenceModal({required this.disputeId, required this.onSuccess});

  @override
  State<_AddEvidenceModal> createState() => _AddEvidenceModalState();
}

class _AddEvidenceModalState extends State<_AddEvidenceModal> {
  final _noteController = TextEditingController();
  final List<XFile> _selectedImages = [];
  bool _isSubmitting = false;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        for (final img in picked) {
          if (_selectedImages.length < 5) {
            _selectedImages.add(img);
          }
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final api = sl<ApiService>();
      final List<String> fileIds = [];

      for (final image in _selectedImages) {
        final res = await api.postMultipart(
          '/files',
          fieldName: 'file',
          filePath: image.path,
          fields: {'purpose': 'DISPUTE_EVIDENCE'},
        );
        if (res != null && res['data']?['id'] != null) {
          fileIds.add(res['data']['id'].toString());
        }
      }

      if (!mounted) return;
      final cubit = context.read<DisputeCubit>();
      await cubit.submitEvidence(
        disputeId: widget.disputeId,
        note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
        fileIds: fileIds.isNotEmpty ? fileIds : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.black, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TAMBAH BUKTI SENGKETA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tulis penjelasan bukti tambahan...',
              border: OutlineInputBorder(borderSide: const BorderSide(color: AppColors.black, width: 2), borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _selectedImages.length >= 5 ? null : _pickImages,
                icon: const Icon(Icons.photo_library_outlined, size: 18, color: Colors.black),
                label: Text('Foto (${_selectedImages.length}/5)', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.paleYellow,
                  side: const BorderSide(color: AppColors.black, width: 2),
                ),
              ),
            ],
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _selectedImages.map((img) {
                return Chip(
                  label: Text(img.name, style: const TextStyle(fontSize: 11)),
                  onDeleted: () => setState(() => _selectedImages.remove(img)),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          BrutalistButton(
            text: _isSubmitting ? 'MENGUNGGAH...' : 'KIRIM BUKTI',
            backgroundColor: AppColors.black,
            textColor: AppColors.white,
            onPressed: _isSubmitting ? () {} : _submit,
          ),
        ],
      ),
    );
  }
}
