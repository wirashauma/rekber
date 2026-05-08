import 'package:flutter/material.dart';

/// REKBER Design System - Color Palette
/// Inspired by Kupa reference app with escrow-specific adaptations
class AppColors {
  AppColors._();

  // ── Primary (Deep Emerald Green) ──
  static const Color primary = Color(0xFF1B5E37);
  static const Color primaryLight = Color(0xFF2D7A4A);
  static const Color primaryDark = Color(0xFF0F3D22);
  static const Color primarySurface = Color(0xFFE8F5EC);

  // ── Accent (Gold - for money/escrow highlights) ──
  static const Color accent = Color(0xFFD4A844);
  static const Color accentLight = Color(0xFFF5E6C4);
  static const Color accentDark = Color(0xFFB8892E);

  // ── Neutral ──
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F5);
  static const Color border = Color(0xFFE0E3E7);
  static const Color divider = Color(0xFFEEF0F2);

  // ── Text ──
  static const Color textPrimary = Color(0xFF1A1D21);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFF1A1D21);

  // ── Status Colors ──
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ── Transaction Status Colors ──
  static const Color statusAwaitingPayment = Color(0xFFF59E0B);
  static const Color statusEscrow = Color(0xFF3B82F6);
  static const Color statusProcessed = Color(0xFF8B5CF6);
  static const Color statusShipped = Color(0xFF06B6D4);
  static const Color statusCompleted = Color(0xFF22C55E);
  static const Color statusDisputed = Color(0xFFEF4444);
  static const Color statusRefunded = Color(0xFF6B7280);
  static const Color statusCancelled = Color(0xFF9CA3AF);

  // ── Gradient Definitions ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentLight],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary, Color(0xFF245E3A), primaryLight],
  );

  /// Get color for transaction status
  static Color getStatusColor(String status) {
    switch (status) {
      case 'awaiting_payment':
        return statusAwaitingPayment;
      case 'escrow':
        return statusEscrow;
      case 'processed':
        return statusProcessed;
      case 'shipped':
        return statusShipped;
      case 'completed':
        return statusCompleted;
      case 'disputed':
        return statusDisputed;
      case 'refunded':
        return statusRefunded;
      case 'cancelled':
        return statusCancelled;
      default:
        return textTertiary;
    }
  }

  /// Get light background for transaction status
  static Color getStatusBackgroundColor(String status) {
    return getStatusColor(status).withOpacity(0.12);
  }
}
