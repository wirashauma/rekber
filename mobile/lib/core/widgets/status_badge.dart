import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Transaction status badge with dynamic colors
class StatusBadge extends StatelessWidget {
  final String status;
  final bool isCompact;

  const StatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getStatusColor(status);
    final bgColor = AppColors.getStatusBackgroundColor(status);
    final label = _getStatusLabel(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? AppDimensions.sm : AppDimensions.md,
        vertical: isCompact ? 2 : AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: isCompact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    const labels = {
      'awaiting_payment': 'Menunggu Bayar',
      'escrow': 'Dana Ditahan',
      'processed': 'Diproses',
      'shipped': 'Dikirim',
      'completed': 'Selesai',
      'disputed': 'Sengketa',
      'refunded': 'Dikembalikan',
      'cancelled': 'Dibatalkan',
    };
    return labels[status] ?? status;
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
