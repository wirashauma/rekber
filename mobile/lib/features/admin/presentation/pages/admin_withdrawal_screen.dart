import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/brutal_skeleton.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/admin_cubit.dart';
import '../cubit/admin_state.dart';

class AdminWithdrawalScreen extends StatefulWidget {
  const AdminWithdrawalScreen({super.key});

  @override
  State<AdminWithdrawalScreen> createState() => _AdminWithdrawalScreenState();
}

class _AdminWithdrawalScreenState extends State<AdminWithdrawalScreen> {
  String selectedFilter = 'PENDING_REVIEW';

  final List<String> filters = [
    'PENDING_REVIEW',
    'APPROVED',
    'PROCESSING',
    'COMPLETED',
    'REJECTED',
    'Semua',
  ];

  @override
  void initState() {
    super.initState();
    context.read<AdminCubit>().loadWithdrawals(status: selectedFilter);
  }

  void _onFilterChanged(String filter) {
    setState(() => selectedFilter = filter);
    context.read<AdminCubit>().loadWithdrawals(status: filter);
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

  String _getFilterLabel(String f) {
    switch (f) {
      case 'PENDING_REVIEW':
        return 'PERLU TINJAU';
      case 'APPROVED':
        return 'DISETUJUI';
      case 'PROCESSING':
        return 'DIPROSES';
      case 'COMPLETED':
        return 'SELESAI';
      case 'REJECTED':
        return 'DITOLAK';
      default:
        return 'SEMUA';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return AppColors.tealGreen;
      case 'APPROVED':
      case 'PROCESSING':
        return Colors.cyanAccent;
      case 'PENDING_REVIEW':
        return Colors.orangeAccent;
      case 'REJECTED':
      case 'FAILED':
        return Colors.redAccent;
      default:
        return Colors.yellowAccent;
    }
  }

  void _showApproveConfirmation(BuildContext context, String withdrawalId, String amountStr, String user) {
    final cubit = context.read<AdminCubit>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppColors.black, width: 3),
        ),
        title: Text(
          'SETUJUI PENARIKAN',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: Text(
          'Setujui penarikan $amountStr untuk $user? Payout akan dikirimkan ke payment gateway.',
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
            text: 'YA, SETUJUI',
            backgroundColor: AppColors.tealGreen,
            textColor: AppColors.white,
            height: 40,
            width: 130,
            onPressed: () {
              Navigator.pop(ctx);
              cubit.approveWithdrawal(
                    withdrawalId,
                    currentFilter: selectedFilter,
                  );
            },
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, String withdrawalId, String user) {
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
          'TOLAK PENARIKAN',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tolak penarikan $user. Dana yang dicadangkan akan dikembalikan ke saldo pengguna.',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                maxLines: 2,
                style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold),
                validator: (val) {
                  final text = (val ?? '').trim();
                  if (text.isEmpty) return 'Alasan penolakan wajib diisi.';
                  if (text.length < 5) return 'Alasan minimal 5 karakter.';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Contoh: Nama rekening tidak sesuai data identitas...',
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
            text: 'TOLAK PENARIKAN',
            backgroundColor: Colors.redAccent,
            textColor: AppColors.white,
            height: 40,
            width: 150,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final reason = reasonController.text.trim();
                Navigator.pop(ctx);
                cubit.rejectWithdrawal(
                      id: withdrawalId,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'PERSETUJUAN PENARIKAN',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w900,
            color: AppColors.black,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: AppColors.black, height: 2),
        ),
      ),
      body: Column(
        children: [
          // ── FILTER TABS ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                  final isSelected = selectedFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: BrutalistBounce(
                      onTap: () => _onFilterChanged(f),
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
                        child: Text(
                          _getFilterLabel(f),
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── WITHDRAWALS LIST ──
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
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        BrutalSkeleton(width: double.infinity, height: 140),
                        SizedBox(height: 12),
                        BrutalSkeleton(width: double.infinity, height: 140),
                      ],
                    ),
                  );
                }

                final loaded = state is AdminWithdrawalsLoaded ? state : null;
                final items = loaded?.withdrawals ?? [];

                if (items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () =>
                        context.read<AdminCubit>().loadWithdrawals(status: selectedFilter),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined,
                                  size: 56, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak Ada Penarikan',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tidak ada data penarikan pada filter ini.',
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
                      context.read<AdminCubit>().loadWithdrawals(status: selectedFilter),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _buildWithdrawalCard(context, items[index]);
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

  Widget _buildWithdrawalCard(BuildContext context, Map<String, dynamic> item) {
    final id = item['id'] as String;
    final status = item['status']?.toString() ?? 'PENDING_REVIEW';
    final amount = (item['amount'] as num?)?.toInt() ?? 0;
    final fee = (item['fee'] as num?)?.toInt() ?? 0;
    final user = item['user'] as Map<String, dynamic>?;
    final userName = user?['name']?.toString() ?? 'Pengguna';
    final userEmail = user?['email']?.toString() ?? '-';
    final bankAccount = item['bankAccount'] as Map<String, dynamic>?;
    final bankCode = bankAccount?['bankCode']?.toString() ?? '-';
    final accountLast4 = bankAccount?['accountLast4']?.toString() ?? '****';
    final accountName = bankAccount?['accountName']?.toString() ?? '-';
    final nameMatch = (item['nameMatch'] as num?)?.toInt() ?? 0;
    final isPending = status == 'PENDING_REVIEW';

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BrutalistBadge(
                  text: status,
                  backgroundColor: _getStatusColor(status),
                ),
                Text(
                  _formatRupiah(amount),
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRow('Pengguna:', '$userName ($userEmail)'),
            _buildRow('Tujuan:', '$bankCode - •••• $accountLast4'),
            _buildRow('Nama Rekening:', accountName),
            _buildRow('Biaya Fee:', _formatRupiah(fee)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Kecocokan Nama: ',
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: nameMatch >= 80 ? Colors.green[100] : Colors.amber[100],
                  child: Text(
                    '$nameMatch%',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: nameMatch >= 80 ? Colors.green[900] : Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: BrutalistButton(
                      text: 'SETUJUI',
                      backgroundColor: AppColors.tealGreen,
                      textColor: AppColors.white,
                      height: 40,
                      borderRadius: 4,
                      onPressed: () => _showApproveConfirmation(
                        context,
                        id,
                        _formatRupiah(amount),
                        userName,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BrutalistButton(
                      text: 'TOLAK',
                      backgroundColor: Colors.redAccent,
                      textColor: AppColors.white,
                      height: 40,
                      borderRadius: 4,
                      onPressed: () => _showRejectDialog(context, id, userName),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
