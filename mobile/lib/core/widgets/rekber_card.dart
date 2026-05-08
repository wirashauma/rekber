import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Reusable card with optional status-colored left border accent
class RekberCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? statusColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const RekberCard({
    super.key,
    required this.child,
    this.onTap,
    this.statusColor,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: AppDimensions.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Row(
            children: [
              // Status color accent bar
              if (statusColor != null)
                Container(
                  width: 4,
                  height: 60,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppDimensions.radiusLg),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: padding ??
                      const EdgeInsets.all(AppDimensions.base),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
