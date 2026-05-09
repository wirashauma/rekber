import 'package:flutter/material.dart';

/// REKBER Design System - Neo-Brutalism (Saweria Style)
class AppColors {
  AppColors._();

  // ── Core Neo-Brutalism Palette ──
  static const Color primary = deepPurple; // Deep Purple
  static const Color secondary = neonGreen; // Neon Green
  static const Color accent = neonGreen; // Neon Green
  
  // ── Multi-Color Neo-Brutalist Palette ──
  static const Color deepPurple = Color(0xFF6236FF);
  static const Color mustardYellow = Color(0xFFFFD500);
  static const Color brightBlue = Color(0xFF4169E1);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color hotPink = Color(0xFFFF6B6B);
  static const Color paleYellow = Color(0xFFFFF9C4);
  static const Color lightBlue = Color(0xFFB3E5FC);

  static const Color black = Color(0xFF000000); // Stark Black
  static const Color white = Color(0xFFFFFFFF); // Pure White
  static const Color background = Color(0xFFF8F9FA); // Off-white/Light Gray
  
  static const Color border = Color(0xFF121212); // Thick Black Borders
  static const Color shadow = Color(0xFF121212); // Solid Hard Shadows

  // ── Compatibility Aliases (Mapping old names to new style) ──
  static const Color surface = white;
  static const Color surfaceVariant = background;
  static const Color primarySurface = primary;
  static const Color accentLight = accent;
  static const Color accentDark = accent;

  // ── Text ──
  static const Color textPrimary = black;
  static const Color textSecondary = Color(0xFF4A4A4A);
  static const Color textTertiary = Color(0xFF757575);
  static const Color textOnPrimary = black;
  static const Color textOnSecondary = white;
  static const Color textOnBlack = white;

  // ── Status Colors (Solid) ──
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF1C40F);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);

  // ── Transaction Status Colors ──
  static const Color statusAwaitingPayment = Color(0xFFFF9F43);
  static const Color statusEscrow = Color(0xFF54a0ff);
  static const Color statusProcessed = Color(0xFF5f27cd);
  static const Color statusCompleted = Color(0xFF10ac84);
  static const Color statusDisputed = Color(0xFFee5253);
  static const Color statusShipped = Color(0xFF00d2d3);

  // ── Gradient Definitions (Compatibility) ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primary],
  );
  static const LinearGradient heroGradient = primaryGradient;

  /// Get color for transaction status
  static Color getStatusColor(String status) {
    switch (status) {
      case 'awaiting_payment':
        return statusAwaitingPayment;
      case 'escrow':
        return statusEscrow;
      case 'processed':
        return statusProcessed;
      case 'completed':
        return statusCompleted;
      case 'disputed':
        return statusDisputed;
      case 'shipped':
        return statusShipped;
      default:
        return textSecondary;
    }
  }

  /// Get light background for transaction status
  static Color getStatusBackgroundColor(String status) {
    return getStatusColor(status).withValues(alpha: 0.2);
  }
}
