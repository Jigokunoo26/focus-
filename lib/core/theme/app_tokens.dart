import 'package:flutter/material.dart';

/// Design tokens for spacing, corner radius, blur, elevation and animations.
class AppTokens {
  AppTokens._();

  // Spacing
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;

  // Corner Radii (Smooth Squircle-style curves)
  static const double radiusSmall = 10.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 22.0;
  static const double radiusFull = 999.0;

  static const BorderRadius borderSmall = BorderRadius.all(Radius.circular(radiusSmall));
  static const BorderRadius borderMedium = BorderRadius.all(Radius.circular(radiusMedium));
  static const BorderRadius borderLarge = BorderRadius.all(Radius.circular(radiusLarge));
  static const BorderRadius borderPill = BorderRadius.all(Radius.circular(radiusFull));

  // Frosted Glass Blur Strengths
  static const double blurLight = 10.0;
  static const double blurStandard = 18.0;
  static const double blurHeavy = 28.0;

  // Animation Durations
  static const Duration durationFast = Duration(milliseconds: 140);
  static const Duration durationStandard = Duration(milliseconds: 240);
  static const Duration durationLong = Duration(milliseconds: 360);

  // Animation Curves (Apple-style smooth decelerations)
  static const Curve curveStandard = Curves.easeOutCubic;
  static const Curve curveSpring = Curves.easeOutBack;
}
