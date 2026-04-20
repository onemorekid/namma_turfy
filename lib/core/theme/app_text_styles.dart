import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Named text styles matching the Namma Turfy design spec.
/// Font family: Outfit (loaded via google_fonts).
class AppTextStyles {
  AppTextStyles._();

  // ── Display ───────────────────────────────────────────────────────────────

  /// 32 sp Bold — app name on splash/login
  static TextStyle get displayLarge => GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      );

  // ── Headline ──────────────────────────────────────────────────────────────

  /// 24 sp Bold — screen titles ("Booking Confirmed!")
  static TextStyle get headlineMedium => GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      );

  // ── Title ─────────────────────────────────────────────────────────────────

  /// 20 sp SemiBold — app bar titles, card venue names
  static TextStyle get titleLarge => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  /// 16 sp SemiBold — section headers ("Popular Turfs")
  static TextStyle get titleMedium => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  // ── Body ──────────────────────────────────────────────────────────────────

  /// 16 sp Regular — slot times, primary body
  static TextStyle get bodyLarge => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  /// 14 sp Regular — secondary body, descriptions
  static TextStyle get bodyMedium => GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  /// 12 sp Regular — captions, distance labels, reviews count
  static TextStyle get bodySmall => GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurfaceVar,
      );

  // ── Label ─────────────────────────────────────────────────────────────────

  /// 16 sp Bold — button text
  static TextStyle get labelLarge => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      );

  /// 14 sp SemiBold — badge/chip text
  static TextStyle get labelMedium => GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  /// 11 sp Medium — bottom nav labels
  static TextStyle get labelSmall => GoogleFonts.outfit(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurfaceVar,
      );

  // ── Price variants ────────────────────────────────────────────────────────

  /// Regular price — Bold onSurface
  static TextStyle get priceRegular => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      );

  /// Peak-time price — Bold peakTime colour
  static TextStyle get pricePeak => GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.peakTime,
      );

  /// Total / CTA price — Bold primary colour
  static TextStyle get priceTotal => GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      );
}
