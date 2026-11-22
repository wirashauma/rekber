import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class AdminDisputeScreen extends StatefulWidget {
  const AdminDisputeScreen({super.key});

  @override
  State<AdminDisputeScreen> createState() => _AdminDisputeScreenState();
}

class _AdminDisputeScreenState extends State<AdminDisputeScreen> {
  String selectedFilter = 'Semua';

  final List<String> filters = [
    'Semua',
    'OPEN',
    'UNDER_REVIEW',
    'RESOLVED_BUYER',
    'RESOLVED_SELLER',
  ];

  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadDisputes(status: selectedFilter);
  }

  void _onFilterChanged(String filter) {
    setState(() => selectedFilter = filter);
    context.read<AdminCubit>().loadDisputes(status: filter);
  }

  String _formatRupiah(int amount) {
    final s = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return 'Rp ${buffer.toString().split('').reversed.join('')}';
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case 'OPEN':
        return 'BARU (OPEN)';
      case 'UNDER_REVIEW':
        return 'SEDANG DITINJAU';
      case 'RESOLVED_BUYER':
        return 'SELESAI (PEMBELI)';
      case 'RESOLVED_SELLER':
        return 'SELESAI (PENJUAL)';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.redAccent;
      case 'UNDER_REVIEW':
        return Colors.orangeAccent;
      case 'RESOLVED_BUYER':
      case 'RESOLVED_SELLER':
        return AppColors.tealGreen;
      default:
        return Colors.grey;
    }
  }

  void _showResolutionDialog(BuildContext context, Map<String, dynamic> dispute) {
    final cubit = context.read<AdminCubit>();
    final disputeId = dispute['id'] as String;
    final txCode = dispute['transaction']?['code'] ?? dispute['transactionId'] ?? disputeId;
    String decision = 'RELEASE_TO_SELLER';
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: AppColors.white,
            shape: const RoundedRectangleBorder(
              side: BorderSide(color: AppColors.black, width: 3),
            ),
            title: Text(
              'PUTUSAN SENGKETA',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaksi: $txCode',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'LANGKAH 1: PILIH PEMENANG',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      value: 'RELEASE_TO_SELLER',
                      groupValue: decision,
                      activeColor: AppColors.black,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Menangkan Penjual (Lepas Dana)',
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Dana escrow diteruskan ke penjual.',
                        style: GoogleFonts.spaceGrotesk(fontSize: 11),
                      ),
                      onChanged: (val) {
                        if (val != null) setModalState(() => decision = val);
                      },
                    ),
                    RadioListTile<String>(
                      value: 'REFUND_TO_BUYER',
                      groupValue: decision,
                      activeColor: AppColors.black,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Menangkan Pembeli (Refund Dana)',
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Dana escrow dikembalikan ke saldo pembeli.',
                        style: GoogleFonts.spaceGrotesk(fontSize: 11),
                      ),
                      onChanged: (val) {
                        if (val != null) setModalState(() => decision = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'LANGKAH 2: CATATAN PUTUSAN (WAJIB)',
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: noteController,
                      maxLines: 3,
                      style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold),
                      validator: (val) {
                        final text = (val ?? '').trim();
                        if (text.isEmpty) return 'Catatan putusan wajib diisi.';
                        if (text.length < 10) return 'Catatan minimal 10 karakter (saat ini ${text.length}).';
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Tuliskan dasar pertimbangan dan bukti putusan...',
                        hintStyle: GoogleFonts.spaceGrotesk(fontSize: 12, color: Colors.grey),
                        filled: true,
                        fillColor: AppColors.white,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: AppColors.black, width: 2),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: AppColors.black, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
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
                text: 'EKSEKUSI PUTUSAN',
                backgroundColor: AppColors.black,
                textColor: AppColors.white,
                height: 42,
                width: 160,
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final note = noteController.text.trim();
                    Navigator.pop(ctx);
                    cubit.resolveDispute(
                          id: disputeId,
                          decision: decision,
                          note: note,
                          currentFilter: selectedFilter,
                        );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReviewConfirmation(BuildContext context, String disputeId) {
    final cubit = context.read<AdminCubit>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.black, width: 3),
        ),
        title: Text(
          'TINJAU SENGKETA',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Ubah status sengketa menjadi SEDANG DITINJAU (UNDER_REVIEW)? Kedua belah pihak akan diberitahu bahwa admin sedang memeriksa bukti.',
          style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.bold),
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
            text: 'YA, TINJAU',
            backgroundColor: Colors.orangeAccent,
            height: 40,
            width: 120,
            onPressed: () {
              Navigator.pop(ctx);
              cubit.reviewDispute(disputeId, currentFilter: selectedFilter);
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
          'MODERASI SENGKETA',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppColors.white,
          ),
        ),
        backgroundColor: Colors.redAccent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── FILTER CHIPS ──
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.black, width: 2),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final filter = filters[index];
                final isSelected = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: BrutalistBounce(
                    onTap: () => _onFilterChanged(filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                      child: Center(
                        child: Text(
                          filter == 'Semua' ? 'SEMUA' : _formatStatusLabel(filter),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── DISPUTE LIST ──
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
                        BrutalSkeleton(width: double.infinity, height: 160),
                        SizedBox(height: 16),
                        BrutalSkeleton(width: double.infinity, height: 160),
                      ],
                    ),
                  );
                }

                final disputesLoaded = state is AdminDisputesLoaded ? state : null;
                final disputes = disputesLoaded?.disputes ?? [];

                if (disputes.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => context.read<AdminCubit>().loadDisputes(status: selectedFilter),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 56, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak Ada Sengketa',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Semua transaksi berjalan lancar.',
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
                  onRefresh: () => context.read<AdminCubit>().loadDisputes(status: selectedFilter),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: disputes.length,
                    itemBuilder: (context, index) {
                      return _buildDisputeCard(context, disputes[index]);
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

  Widget _buildDisputeCard(BuildContext context, Map<String, dynamic> dispute) {
    final disputeId = dispute['id'] as String;
    final transaction = dispute['transaction'] as Map<String, dynamic>?;
    final txCode = transaction?['code'] ?? dispute['transactionId'] ?? disputeId;
    final reason = dispute['reason']?.toString() ?? 'OTHER';
    final description = dispute['description']?.toString() ?? '-';
    final status = dispute['status']?.toString() ?? 'OPEN';
    final buyer = transaction?['buyer'] as Map<String, dynamic>?;
    final seller = transaction?['seller'] as Map<String, dynamic>?;
    final buyerName = buyer?['name'] ?? '-';
    final sellerName = seller?['name'] ?? '-';
    final amount = (transaction?['amount'] as num?)?.toInt() ?? 0;
    final isOpen = status == 'OPEN';
    final isUnderReview = status == 'UNDER_REVIEW';
    final canResolve = isOpen || isUnderReview;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: BrutalistCard(
        backgroundColor: AppColors.white,
        padding: const EdgeInsets.all(16),
        borderRadius: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BrutalistBadge(
                  text: _formatStatusLabel(status),
                  backgroundColor: _getStatusColor(status),
                ),
                Text(
                  txCode,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'ALASAN: $reason',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Pembeli:', buyerName),
            _buildInfoRow('Penjual:', sellerName),
            _buildInfoRow('Nilai Transaksi:', _formatRupiah(amount), isBold: true),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: BrutalistButton(
                    text: 'MASUK CHAT',
                    backgroundColor: Colors.cyanAccent,
                    height: 42,
                    borderRadius: 4,
                    icon: Icons.chat_rounded,
                    onPressed: () {
                      final txid = dispute['transactionId'] ?? '';
                      context.push('/admin/dispute/chat/$txid');
                    },
                  ),
                ),
                if (isOpen) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: BrutalistButton(
                      text: 'TINJAU',
                      backgroundColor: Colors.orangeAccent,
                      height: 42,
                      borderRadius: 4,
                      onPressed: () => _showReviewConfirmation(context, disputeId),
                    ),
                  ),
                ],
                if (canResolve) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: BrutalistButton(
                      text: 'PUTUSKAN',
                      backgroundColor: AppColors.black,
                      textColor: AppColors.white,
                      height: 42,
                      borderRadius: 4,
                      onPressed: () => _showResolutionDialog(context, dispute),
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

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
