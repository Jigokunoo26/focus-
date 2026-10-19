import 'package:flutter/material.dart';

/// Centralized color palette following the Nothing OS monochrome + Apple frosted glass design language.
class AppColors {
  // Prevent instantiation
  AppColors._();

  // Dark Theme Foundations (Default)
  static const Color darkBackground = Color(0xFF090A0C);
  static const Color darkSurface = Color(0xFF111215);
  static const Color darkCard = Color(0xFF17181C);
  static const Color darkCardHover = Color(0xFF1E2026);
  static const Color darkGlassBackground = Color(0x18FFFFFF);
  static const Color darkGlassBorder = Color(0x1AFFFFFF);
  static const Color darkGlassHighlight = Color(0x0DFFFFFF);

  // Light Theme Foundations
  static const Color lightBackground = Color(0xFFF6F7F9);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF0F2F5);
  static const Color lightCardHover = Color(0xFFE4E7EC);
  static const Color lightGlassBackground = Color(0xB8FFFFFF);
  static const Color lightGlassBorder = Color(0x1F000000);
  static const Color lightGlassHighlight = Color(0x33FFFFFF);

  // Monochrome Scale
  static const Color white = Color(0xFFFFFFFF);
  static const Color textPrimaryDark = Color(0xFFF7F8F9);
  static const Color textSecondaryDark = Color(0xFF8F939D);
  static const Color textTertiaryDark = Color(0xFF585C66);

  static const Color textPrimaryLight = Color(0xFF0C0D0E);
  static const Color textSecondaryLight = Color(0xFF667085);
  static const Color textTertiaryLight = Color(0xFF98A2B3);

  // Single Restrained Accent: Signal Vermilion / Flame
  static const Color accent = Color(0xFFFF3B30);
  static const Color accentMuted = Color(0x26FF3B30);
  static const Color accentSubtle = Color(0x14FF3B30);

  // Functional Status Colors (Subtle & Restrained)
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color info = Color(0xFF0A84FF);
  static const Color urgent = Color(0xFFFF453A);
  
  // Matrix / Dot details
  static const Color dotMatrixDim = Color(0x2EFFFFFF);
  static const Color dotMatrixActive = Color(0xB3FFFFFF);
}
