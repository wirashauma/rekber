import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/brutalist_widgets.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../wallet/presentation/cubit/wallet_cubit.dart';
import '../../../wallet/presentation/cubit/wallet_state.dart';
import '../cubit/transaction_cubit.dart';
import '../cubit/transaction_state.dart';
import '../../../../injection_container.dart';
import '../../../../core/services/api_service.dart';
import '../../../dispute/presentation/cubit/dispute_cubit.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/escrow_state_machine.dart';

/// Transaction Detail Page — Full escrow tracking with role actions and live countdown
class TransactionDetailPage extends StatefulWidget {
  final String transactionId;
  final TransactionEntity? initialTransaction;

  const TransactionDetailPage({
    super.key,
    required this.transactionId,
    this.initialTransaction,
  });

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  Timer? _countdownTimer;
  Duration _remainingAutoRelease = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionCubit>().loadTransactionDetail(widget.transactionId);
      context.read<WalletCubit>().loadWalletData();
    });
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final tx = context.read<TransactionCubit>().currentDetail ?? widget.initialTransaction;
      if (tx != null && tx.autoReleaseAt != null && tx.status == 'SHIPPED') {
        final diff = tx.autoReleaseAt!.difference(DateTime.now());
        if (mounted) {
          setState(() {
            _remainingAutoRelease = diff.isNegative ? Duration.zero : diff;
          });
        }
      }
    });
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return 'Kedaluwarsa / Selesai';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}j ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}d';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TransactionCubit, TransactionState>(
      listener: (context, state) {
        if (state is TransactionActionFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.isConflict
                    ? 'Konflik status terdeteksi: ${state.message}. Data telah diperbarui otomatis.'
                    : 'Gagal: ${state.message}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: state.isConflict ? AppColors.warning : AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (state is TransactionActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: AppColors.success,
            ),
          );
          // Segarkan data wallet & transaksi
          context.read<WalletCubit>().loadWalletData();
          context.read<TransactionCubit>().loadTransactionDetail(widget.transactionId);
        }
      },
      builder: (context, state) {
        final currentTx = (state is TransactionDetailLoaded)
            ? state.transaction
            : (context.read<TransactionCubit>().currentDetail ?? widget.initialTransaction);

        if (state is TransactionLoading && currentTx == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.black)),
          );
        }

        if (currentTx == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Detail Transaksi')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Transaksi tidak ditemukan.', style: AppTextStyles.h3),
                  const SizedBox(height: 12),
                  BrutalistButton(
                    text: 'KEMBALI',
                    backgroundColor: AppColors.black,
                    textColor: AppColors.white,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          );
        }

        final authState = context.watch<AuthBloc>().state;
        final currentUserId = authState is AuthAuthenticated ? authState.user.id : '';
        final isBuyer = currentUserId.isNotEmpty && currentUserId == currentTx.buyerId;
        final isSeller = currentUserId.isNotEmpty && currentUserId == currentTx.sellerId;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              'DETAIL TRANSAKSI',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                color: Colors.black,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.black),
                tooltip: 'Buka Chat',
                onPressed: () => context.push('/chat/${currentTx.id}'),
              ),
            ],
            shape: const Border(bottom: BorderSide(color: Colors.black, width: 2.0)),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: AppDimensions.sm),

                // ── Status Header Card ──
                _buildStatusHeader(currentTx),

                // ── Auto-release Countdown Banner (if SHIPPED) ──
                if (currentTx.status == 'SHIPPED' && currentTx.autoReleaseAt != null)
                  _buildAutoReleaseBanner(),

                // ── Progress Stepper ──
                _buildProgressStepper(currentTx.status),

                // ── Transaction Info ──
                _buildInfoSection(currentTx, isBuyer, isSeller),

                // ── Payment Summary ──
                _buildPaymentSummary(currentTx),

                // ── Shipment Proof Section (if available) ──
                if (currentTx.shipmentProofUrls.isNotEmpty || currentTx.courier != null)
                  _buildShipmentProofSection(currentTx),

                // ── Action Buttons based on Role & State ──
                _buildActionButtons(context, currentTx, isBuyer, isSeller, state),

                const SizedBox(height: AppDimensions.xxl),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(TransactionEntity tx) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.xl),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.getStatusBackgroundColor(tx.status),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: AppColors.getStatusColor(tx.status).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.getStatusColor(tx.status).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(
              _getStatusIcon(tx.status),
              color: AppColors.getStatusColor(tx.status),
              size: 28,
            ),
          ),
          const SizedBox(width: AppDimensions.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(status: tx.status),
                const SizedBox(height: 6),
                Text(
                  EscrowStateMachine.getStatusDescription(tx.status),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getStatusColor(tx.status),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoReleaseBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.xl, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paleYellow,
        border: Border.all(color: AppColors.black, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.black, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto-Release Otomatis',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                ),
                Text(
                  'Dana diteruskan ke penjual dalam: ${_formatDuration(_remainingAutoRelease)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStepper(String currentStatus) {
    const steps = EscrowStateMachine.statusOrder;
    final currentIndex = EscrowStateMachine.getStepIndex(currentStatus);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.xl, vertical: 8),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status Pesanan', style: AppTextStyles.labelLarge),
          const SizedBox(height: AppDimensions.base),
          ...List.generate(steps.length, (index) {
            final isCompleted = index <= currentIndex;
            final isCurrent = index == currentIndex;
            final isLast = index == steps.length - 1;
            final stepStatus = steps[index];

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCompleted ? AppColors.getStatusColor(stepStatus) : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted ? AppColors.getStatusColor(stepStatus) : AppColors.textTertiary,
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(Icons.check, size: 14, color: AppColors.white)
                          : null,
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 32,
                        color: index < currentIndex
                            ? AppColors.getStatusColor(steps[index + 1])
                            : AppColors.border,
                      ),
                  ],
                ),
                const SizedBox(width: AppDimensions.base),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          EscrowStateMachine.getStatusLabel(stepStatus),
                          style: AppTextStyles.labelMedium.copyWith(
                            color: isCurrent
                                ? AppColors.textPrimary
                                : isCompleted
                                    ? AppColors.textSecondary
                                    : AppColors.textTertiary,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        if (isCurrent)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              EscrowStateMachine.getStatusDescription(stepStatus),
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoSection(TransactionEntity tx, bool isBuyer, bool isSeller) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.xl, vertical: 8),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Informasi Transaksi', style: AppTextStyles.labelLarge),
              Text(
                'Peran: ${isBuyer ? 'Pembeli' : (isSeller ? 'Penjual' : 'Pihak Terkait')}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.tealGreen),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          _buildInfoRow('Kode Transaksi', tx.txCode, isCopyable: true),
          _buildInfoRow('Deskripsi', tx.description ?? '-'),
          _buildInfoRow('Penjual', tx.sellerName ?? tx.sellerEmail ?? 'Penjual'),
          _buildInfoRow('Pembeli', tx.buyerName ?? tx.buyerEmail ?? 'Pembeli'),
          _buildInfoRow(
            'Tanggal Dibuat',
            '${tx.createdAt.day.toString().padLeft(2, '0')}/${tx.createdAt.month.toString().padLeft(2, '0')}/${tx.createdAt.year} ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isCopyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (isCopyable)
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kode transaksi disalin ke clipboard!')),
                      );
                    },
                    child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(TransactionEntity tx) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.xl, vertical: 8),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rincian Pembayaran', style: AppTextStyles.labelLarge),
          const SizedBox(height: AppDimensions.md),
          _buildPaymentRow('Harga Barang', CurrencyFormatter.format(tx.amount)),
          _buildPaymentRow('Fee Rekber (${tx.feePayer})', CurrencyFormatter.format(tx.platformFee)),
          const Divider(height: AppDimensions.xl),
          _buildPaymentRow(
            'Total Pembeli Bayar',
            CurrencyFormatter.format(tx.totalAmount),
            isTotal: true,
          ),
          _buildPaymentRow(
            'Net Penjual Terima',
            CurrencyFormatter.format(tx.sellerReceives),
            isSecondaryTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, {bool isTotal = false, bool isSecondaryTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: (isTotal || isSecondaryTotal)
                ? AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700)
                : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: isTotal
                ? AppTextStyles.h4.copyWith(color: AppColors.primary)
                : isSecondaryTotal
                    ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.success)
                    : AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void _openShipmentProofViewer(String urlOrId) async {
    String displayUrl = urlOrId;
    if (!urlOrId.startsWith('http')) {
      try {
        final api = sl<ApiService>();
        final res = await api.get('/files/$urlOrId/url');
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

  Widget _buildShipmentProofSection(TransactionEntity tx) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.xl, vertical: 8),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bukti Pengiriman', style: AppTextStyles.labelLarge),
          const SizedBox(height: AppDimensions.md),
          if (tx.courier != null) _buildInfoRow('Kurir', tx.courier!),
          if (tx.trackingNumber != null) _buildInfoRow('Nomor Resi', tx.trackingNumber!, isCopyable: true),
          if (tx.shipmentNote != null) _buildInfoRow('Catatan', tx.shipmentNote!),
          if (tx.shipmentProofUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tx.shipmentProofUrls.map((url) {
                return GestureDetector(
                  onTap: () => _openShipmentProofViewer(url),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported_rounded),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    TransactionEntity tx,
    bool isBuyer,
    bool isSeller,
    TransactionState state,
  ) {
    final isLoading = state is TransactionActionLoading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl, vertical: AppDimensions.md),
      child: Column(
        children: [
          // Pembeli: PENDING -> Bayar dari Saldo & Batalkan
          if (isBuyer && tx.status == 'PENDING') ...[
            BrutalistButton(
              text: isLoading ? 'MEMPROSES...' : 'BAYAR DARI SALDO',
              backgroundColor: AppColors.tealGreen,
              textColor: AppColors.black,
              onPressed: isLoading ? () {} : () => _onPayFromBalancePressed(tx),
            ),
            const SizedBox(height: 12),
            BrutalistButton(
              text: 'BATALKAN TRANSAKSI',
              backgroundColor: AppColors.paleYellow,
              textColor: AppColors.black,
              onPressed: isLoading ? () {} : () => _onCancelTransactionPressed(tx),
            ),
          ],

          // Pembeli: PAID -> Ajukan Sengketa
          if (isBuyer && tx.status == 'PAID') ...[
            BrutalistButton(
              text: 'AJUKAN SENGKETA',
              backgroundColor: AppColors.error.withValues(alpha: 0.15),
              textColor: AppColors.error,
              onPressed: () => _onDisputePressed(tx),
            ),
            const SizedBox(height: 12),
          ],

          // Pembeli: SHIPPED -> Konfirmasi Diterima & Sengketa
          if (isBuyer && tx.status == 'SHIPPED') ...[
            BrutalistButton(
              text: isLoading ? 'MEMPROSES...' : 'KONFIRMASI DITERIMA',
              backgroundColor: AppColors.tealGreen,
              textColor: AppColors.black,
              onPressed: isLoading ? () {} : () => _onConfirmReceivedPressed(tx),
            ),
            const SizedBox(height: 12),
            BrutalistButton(
              text: 'AJUKAN SENGKETA',
              backgroundColor: AppColors.error.withValues(alpha: 0.15),
              textColor: AppColors.error,
              onPressed: () => _onDisputePressed(tx),
            ),
            const SizedBox(height: 12),
          ],

          // Status DISPUTED -> Tombol Lihat Detail Sengketa
          if (tx.status == 'DISPUTED') ...[
            BrutalistButton(
              text: 'LIHAT DETAIL SENGKETA',
              backgroundColor: AppColors.error,
              textColor: AppColors.white,
              onPressed: () => context.push('/dispute/${tx.id}'),
            ),
            const SizedBox(height: 12),
          ],

          // Penjual: PAID -> Tandai Dikirim
          if (isSeller && tx.status == 'PAID') ...[
            BrutalistButton(
              text: isLoading ? 'MEMPROSES...' : 'TANDAI DIKIRIM',
              backgroundColor: AppColors.tealGreen,
              textColor: AppColors.black,
              onPressed: isLoading ? () {} : () => _showShipmentModal(tx),
            ),
          ],

          // Penjual: PENDING -> Batalkan
          if (isSeller && tx.status == 'PENDING') ...[
            BrutalistButton(
              text: 'BATALKAN TRANSAKSI',
              backgroundColor: AppColors.paleYellow,
              textColor: AppColors.black,
              onPressed: isLoading ? () {} : () => _onCancelTransactionPressed(tx),
            ),
          ],

          // Tombol Chat Umum
          const SizedBox(height: 12),
          BrutalistButton(
            text: 'BUKA CHAT TRANSAKSI',
            backgroundColor: AppColors.white,
            textColor: AppColors.black,
            onPressed: () => context.push('/chat/${tx.id}'),
          ),
        ],
      ),
    );
  }

  void _onPayFromBalancePressed(TransactionEntity tx) {
    final walletState = context.read<WalletCubit>().state;
    int currentBalance = 0;
    if (walletState is WalletLoaded) {
      currentBalance = walletState.summary.balance;
    }

    if (currentBalance < tx.totalAmount) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Saldo Tidak Mencukupi'),
          content: Text(
            'Saldo Anda saat ini: ${CurrencyFormatter.format(currentBalance)}\n'
            'Total tagihan: ${CurrencyFormatter.format(tx.totalAmount)}\n\n'
            'Silakan isi saldo dompet Anda terlebih dahulu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.black),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.push('/topup');
              },
              child: const Text('Top Up Sekarang', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pembayaran'),
        content: Text(
          'Apakah Anda yakin ingin membayar ${CurrencyFormatter.format(tx.totalAmount)} dari saldo dompet Anda?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealGreen),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<TransactionCubit>().payFromBalance(tx.id);
            },
            child: const Text('Ya, Bayar Sekarang', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onConfirmReceivedPressed(TransactionEntity tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Penerimaan'),
        content: const Text(
          'Pastikan Anda telah memeriksa barang yang dikirim. Setelah konfirmasi, dana akan langsung diteruskan ke rekening penjual dan tidak dapat ditarik kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.tealGreen),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<TransactionCubit>().confirmReceived(tx.id);
            },
            child: const Text('Ya, Barang Diterima', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onCancelTransactionPressed(TransactionEntity tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Transaksi'),
        content: const Text('Apakah Anda yakin ingin membatalkan transaksi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<TransactionCubit>().cancelTransaction(tx.id);
            },
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onDisputePressed(TransactionEntity tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DisputeModal(
        transactionId: tx.id,
        onSuccess: () {
          context.read<TransactionCubit>().loadTransactionDetail(tx.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sengketa berhasil diajukan. Status transaksi kini SENGKETA.', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: AppColors.error,
            ),
          );
        },
      ),
    );
  }

  void _showShipmentModal(TransactionEntity tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShipmentModal(
        transactionId: tx.id,
        onSubmit: (courier, tracking, note, imagePath) {
          context.read<TransactionCubit>().submitShipment(
                id: tx.id,
                courier: courier,
                trackingNumber: tracking,
                note: note,
                proofFilePath: imagePath,
              );
        },
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return Icons.schedule_rounded;
      case 'PAID':
        return Icons.lock_rounded;
      case 'SHIPPED':
        return Icons.local_shipping_rounded;
      case 'COMPLETED':
        return Icons.check_circle_rounded;
      case 'CANCELLED':
        return Icons.cancel_rounded;
      case 'DISPUTED':
        return Icons.warning_rounded;
      case 'REFUNDED':
        return Icons.replay_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

class _ShipmentModal extends StatefulWidget {
  final String transactionId;
  final Function(String courier, String tracking, String? note, String imagePath) onSubmit;

  const _ShipmentModal({
    required this.transactionId,
    required this.onSubmit,
  });

  @override
  State<_ShipmentModal> createState() => _ShipmentModalState();
}

class _ShipmentModalState extends State<_ShipmentModal> {
  final _courierController = TextEditingController(text: 'JNE');
  final _trackingController = TextEditingController();
  final _noteController = TextEditingController();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndCropImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong Bukti Pengiriman',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Potong Bukti Pengiriman',
          ),
        ],
      );

      if (cropped != null) {
        setState(() {
          _imageFile = File(cropped.path);
        });
      } else {
        setState(() {
          _imageFile = File(picked.path);
        });
      }
    } catch (_) {
      // Fallback if cropping fails on some platforms
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.black, width: 3)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TANDAI PESANAN DIKIRIM',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 16),
              const Text('Nama Kurir / Ekspedisi', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              BrutalistTextField(
                controller: _courierController,
                hintText: 'Contoh: JNE / J&T / Digital',
                prefixIcon: Icons.local_shipping_rounded,
              ),
              const SizedBox(height: 12),
              const Text('Nomor Resi / Tautan Pengiriman', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              BrutalistTextField(
                controller: _trackingController,
                hintText: 'Nomor resi pengiriman',
                prefixIcon: Icons.numbers_rounded,
              ),
              const SizedBox(height: 12),
              const Text('Catatan Pengiriman (Opsional)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              BrutalistTextField(
                controller: _noteController,
                hintText: 'Catatan tambahan untuk pembeli',
                prefixIcon: Icons.note_alt_rounded,
              ),
              const SizedBox(height: 16),
              const Text('Foto Bukti Pengiriman / Resi', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickAndCropImage,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_imageFile!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.black),
                            SizedBox(height: 8),
                            Text('Pilih dan potong gambar bukti kirim', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              BrutalistButton(
                text: 'KIRIM BUKTI PENGIRIMAN',
                backgroundColor: AppColors.tealGreen,
                textColor: Colors.black,
                onPressed: () {
                  final courier = _courierController.text.trim();
                  final tracking = _trackingController.text.trim();
                  if (courier.isEmpty || tracking.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kurir dan nomor resi wajib diisi.')),
                    );
                    return;
                  }
                  if (_imageFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unggah bukti pengiriman (foto resi) wajib disertakan.')),
                    );
                    return;
                  }
                  Navigator.of(context).pop();
                  widget.onSubmit(courier, tracking, _noteController.text.trim(), _imageFile!.path);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisputeModal extends StatefulWidget {
  final String transactionId;
  final VoidCallback onSuccess;

  const _DisputeModal({
    required this.transactionId,
    required this.onSuccess,
  });

  @override
  State<_DisputeModal> createState() => _DisputeModalState();
}

class _DisputeModalState extends State<_DisputeModal> {
  final _formKey = GlobalKey<FormState>();
  String _selectedReason = 'NOT_RECEIVED';
  final _descriptionController = TextEditingController();
  final List<XFile> _selectedImages = [];
  bool _isSubmitting = false;

  final Map<String, String> _reasonLabels = {
    'NOT_RECEIVED': 'Barang Tidak Diterima',
    'NOT_AS_DESCRIBED': 'Tidak Sesuai Deskripsi',
    'DEFECTIVE': 'Barang Rusak / Cacat',
    'OTHER': 'Lainnya',
  };

  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) return;

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

  Future<void> _submitDispute() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final api = sl<ApiService>();
      final List<String> fileIds = [];

      for (final img in _selectedImages) {
        final res = await api.postMultipart(
          '/files',
          fieldName: 'file',
          filePath: img.path,
          fields: {'purpose': 'DISPUTE_EVIDENCE'},
        );
        if (res != null && res['data']?['id'] != null) {
          fileIds.add(res['data']['id'].toString());
        }
      }

      if (!mounted) return;
      final disputeCubit = context.read<DisputeCubit>();
      await disputeCubit.openDispute(
        transactionId: widget.transactionId,
        reason: _selectedReason,
        description: _descriptionController.text.trim(),
        fileIds: fileIds.isNotEmpty ? fileIds : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengajukan sengketa: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.black, width: 3)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AJUKAN SENGKETA',
                      style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Alasan
                const Text('Alasan Sengketa', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    border: Border.all(color: AppColors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedReason,
                      items: _reasonLabels.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedReason = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Deskripsi
                const Text('Deskripsi Masalah (min 20 karakter)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    hintText: 'Jelaskan masalah secara rinci untuk ditinjau admin...',
                    border: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.black, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.black, width: 2.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 20) {
                      return 'Deskripsi sengketa minimal 20 karakter.';
                    }
                    if (text.length > 2000) {
                      return 'Deskripsi sengketa maksimal 2000 karakter.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Foto Lampiran
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Lampiran Bukti Foto', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${_selectedImages.length}/5 foto',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _selectedImages.length >= 5 ? AppColors.error : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _selectedImages.length >= 5 ? null : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_rounded, size: 18, color: Colors.black),
                      label: const Text('Pilih Foto', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                    runSpacing: 8,
                    children: _selectedImages.map((img) {
                      return Chip(
                        label: Text(img.name, style: const TextStyle(fontSize: 11)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setState(() => _selectedImages.remove(img)),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 24),
                BrutalistButton(
                  text: _isSubmitting ? 'MENGAJUKAN SENGKETA...' : 'KIRIM SENGKETA',
                  backgroundColor: AppColors.error,
                  textColor: AppColors.white,
                  onPressed: _isSubmitting ? () {} : _submitDispute,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
