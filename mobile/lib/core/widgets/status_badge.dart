import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../../features/transaction/domain/services/escrow_state_machine.dart';

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
    final label = EscrowStateMachine.getStatusLabel(status);
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

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'AWAITING_PAYMENT':
        return Icons.schedule_rounded;
      case 'PAID':
      case 'ESCROW':
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
