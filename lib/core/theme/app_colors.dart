import 'package:flutter/material.dart';

/// All colour tokens for Namma Turfy, derived from the design mockups.
/// Use these constants everywhere — never write raw hex literals in widgets.
class AppColors {
  AppColors._();

  // ── Primary ───────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF35CA67);
  static const Color primaryDark = Color(0xFF1A7A40);
  static const Color primaryLight = Color(0xFFE8F8EE);

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color onSurfaceVar = Color(0xFF666666);
  static const Color outline = Color(0xFFE0E0E0);
  static const Color outlineVariant = Color(0xFFBDBDBD);

  // ── Shadows ───────────────────────────────────────────────────────────────
  /// 5% black — standard card shadow
  static const Color shadowCard = Color(0x0D000000);

  /// 8% black — floating CTA bar shadow
  static const Color shadowFloat = Color(0x14000000);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color peakTime = Color(0xFFFF6B35);
  static const Color peakTimeBg = Color(0xFFFFF0EA);
  static const Color offer = Color(0xFFFF8C00);
  static const Color offerBg = Color(0xFFFFF3DC);
  static const Color star = Color(0xFFFFC107);
  static const Color error = Color(0xFFE53935);
  static const Color errorBg = Color(0xFFFFEBEE);
}
