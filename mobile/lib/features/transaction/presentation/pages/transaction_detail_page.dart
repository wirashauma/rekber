import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/rekber_button.dart';
import '../../../../core/widgets/rekber_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../transaction/domain/services/escrow_state_machine.dart';

/// Transaction Detail Page — Full escrow tracking with state stepper
class TransactionDetailPage extends StatelessWidget {
  // In production, this would receive a TransactionEntity
  const TransactionDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock transaction data for UI development
    const status = 'shipped';
    const txCode = 'RKB-20260508-001234';
    const amount = 2500000;
    const fee = 62500;
    const description = 'iPhone 15 Case Premium - Leather Black';
    const sellerName = 'Toko Elektronik Jakarta';
    const buyerName = 'John Doe';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: AppDimensions.sm),

            // ── Status Header Card ──
            _buildStatusHeader(status),

            // ── Progress Stepper ──
            _buildProgressStepper(status),

            // ── Transaction Info ──
            _buildInfoSection(txCode, description, sellerName, buyerName),

            // ── Payment Summary ──
            _buildPaymentSummary(amount, fee),

            // ── Action Buttons ──
            _buildActionButtons(context, status),

            const SizedBox(height: AppDimensions.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(String status) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.xl),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.getStatusBackgroundColor(status),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: AppColors.getStatusColor(status).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.getStatusColor(status).withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(
              _getStatusIcon(status),
              color: AppColors.getStatusColor(status),
              size: 28,
            ),
          ),
          const SizedBox(width: AppDimensions.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(status: status),
                const SizedBox(height: 6),
                Text(
                  EscrowStateMachine.getStatusDescription(status),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getStatusColor(status),
                    fontWeight: FontWeight.w500,
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

  Widget _buildProgressStepper(String currentStatus) {
    final steps = EscrowStateMachine.statusOrder;
    final currentIndex = EscrowStateMachine.getStepIndex(currentStatus);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
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

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline indicator
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.primary
                            : AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(color: AppColors.primary, width: 3)
                            : null,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                      child: isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 32,
                        color: isCompleted
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                  ],
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: isLast ? 0 : AppDimensions.base,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          EscrowStateMachine.getStatusLabel(steps[index]),
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isCompleted
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                        ),
                        if (isCurrent)
                          Text(
                            EscrowStateMachine.getStatusDescription(steps[index]),
                            style: AppTextStyles.caption,
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

  Widget _buildInfoSection(
    String txCode,
    String description,
    String sellerName,
    String buyerName,
  ) {
    return Container(
      margin: const EdgeInsets.all(AppDimensions.xl),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informasi Transaksi', style: AppTextStyles.labelLarge),
          const SizedBox(height: AppDimensions.base),
          _infoRow('Kode Transaksi', txCode),
          _infoRow('Deskripsi', description),
          _infoRow('Penjual', sellerName),
          _infoRow('Pembeli', buyerName),
          _infoRow('Tanggal', '8 Mei 2026, 10:30'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(int amount, int fee) {
    final total = amount + fee;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ringkasan Pembayaran', style: AppTextStyles.labelLarge),
          const SizedBox(height: AppDimensions.base),
          _paymentRow('Harga Barang', CurrencyFormatter.format(amount)),
          _paymentRow('Biaya Layanan (2.5%)', CurrencyFormatter.format(fee)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTextStyles.labelLarge.copyWith(
                  fontSize: 15,
                ),
              ),
              Text(
                CurrencyFormatter.format(total),
                style: AppTextStyles.currency.copyWith(fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodySmall),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String status) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.xl),
      child: Column(
        children: [
          // Chat button
          RekberButton(
            text: 'Buka Chat',
            icon: Icons.chat_bubble_outline_rounded,
            isOutlined: true,
            onPressed: () {
              // TODO: Navigate to chat room
            },
          ),
          const SizedBox(height: AppDimensions.md),

          // Action buttons based on status
          if (status == 'shipped') ...[
            RekberButton(
              text: 'Pesanan Diterima',
              icon: Icons.check_circle_outline_rounded,
              onPressed: () {
                _showConfirmDialog(context, 'Konfirmasi Penerimaan',
                    'Apakah Anda yakin barang telah diterima? Dana akan dilepas ke penjual.');
              },
            ),
            const SizedBox(height: AppDimensions.sm),
            RekberButton(
              text: 'Ajukan Sengketa',
              icon: Icons.warning_amber_rounded,
              isOutlined: true,
              backgroundColor: AppColors.error,
              onPressed: () {
                _showConfirmDialog(context, 'Ajukan Sengketa',
                    'Apakah Anda yakin ingin mengajukan sengketa? Admin akan meninjau kasus ini.');
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message, style: AppTextStyles.bodyMedium),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Dispatch state transition
            },
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    const icons = {
      'awaiting_payment': Icons.schedule_rounded,
      'escrow': Icons.lock_rounded,
      'processed': Icons.inventory_2_rounded,
      'shipped': Icons.local_shipping_rounded,
      'completed': Icons.check_circle_rounded,
      'disputed': Icons.warning_rounded,
      'refunded': Icons.replay_rounded,
      'cancelled': Icons.cancel_rounded,
    };
    return icons[status] ?? Icons.help_outline_rounded;
  }
}
