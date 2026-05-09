import 'package:flutter/material.dart';
import 'app_colors.dart';

/// REKBER Typography System - Neo-Brutalism (Saweria Style)
class AppTextStyles {
  AppTextStyles._();

  static const String _fontFamily = 'PlusJakartaSans';

  // ── Headings ──
  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w900, // Extra Bold
    color: AppColors.textPrimary,
    height: 1.1,
    letterSpacing: -1.0,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle h4 = h3;

  // ── Body ──
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700, // Bold Body
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // ── Labels (Compatibility) ──
  static const TextStyle labelLarge = bodyLarge;
  static const TextStyle labelMedium = bodyMedium;
  static const TextStyle labelSmall = bodySmall;

  // ── Button ──
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.textOnPrimary,
    letterSpacing: 0.5,
  );

  // ── Special ──
  static const TextStyle currency = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    height: 1.0,
  );

  static const TextStyle currencySmall = bodyLarge;
  static const TextStyle caption = bodySmall;
}
