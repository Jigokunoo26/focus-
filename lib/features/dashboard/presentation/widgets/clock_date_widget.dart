import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_card.dart';

/// Clock & Date Widget featuring Nothing OS large monospace typography and subtle dot-matrix aesthetics.
class ClockDateWidget extends StatefulWidget {
  final VoidCallback? onTap;

  const ClockDateWidget({super.key, this.onTap});

  @override
  State<ClockDateWidget> createState() => _ClockDateWidgetState();
}

class _ClockDateWidgetState extends State<ClockDateWidget> {
  late Timer _timer;
  late DateTime _currentTime;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = DateFormat('HH:mm').format(_currentTime);
    final secStr = DateFormat(':ss').format(_currentTime);
    final dayStr = DateFormat('EEEE').format(_currentTime).toUpperCase();
    final dateStr = DateFormat('d MMMM yyyy').format(_currentTime).toUpperCase();

    return GlassCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.all(AppTokens.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Dot-matrix indicator & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppTokens.space8),
                  Text(
                    'FOCUS OS // LIVE',
                    style: AppTypography.label(isDark: isDark).copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
                  borderRadius: AppTokens.borderSmall,
                  border: Border.all(
                    color: isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'LOCAL // OFFLINE',
                  style: AppTypography.label(isDark: isDark).copyWith(
                    fontSize: 9.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),

          // Monospace Clock
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                timeStr,
                style: AppTypography.clock(isDark: isDark),
              ),
              Text(
                secStr,
                style: AppTypography.clock(isDark: isDark).copyWith(
                  fontSize: 26,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),

          // Date & Day Information
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppTokens.space8,
            runSpacing: 4,
            children: [
              Text(
                dayStr,
                style: AppTypography.titleMedium(isDark: isDark).copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '•',
                style: TextStyle(
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                ),
              ),
              Text(
                dateStr,
                style: AppTypography.bodySmall(isDark: isDark).copyWith(
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
