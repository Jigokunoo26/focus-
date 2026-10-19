import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widget_shell.dart';

class CountdownWidget extends StatefulWidget {
  final String title;
  final DateTime targetDate;

  const CountdownWidget({
    super.key,
    this.title = 'Project MVP Milestone',
    required this.targetDate,
  });

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget> {
  late Timer _timer;
  Duration _difference = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateDifference();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _updateDifference());
  }

  void _updateDifference() {
    final diff = widget.targetDate.difference(DateTime.now());
    if (mounted) {
      setState(() => _difference = diff.isNegative ? Duration.zero : diff);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = _difference.inDays;
    final hours = _difference.inHours % 24;
    final minutes = _difference.inMinutes % 60;

    return WidgetShell(
      title: 'Target Countdown',
      icon: LucideIcons.hourglass,
      statusTag: 'GOAL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: AppTypography.titleMedium(isDark: isDark),
          ),
          const SizedBox(height: AppTokens.space8),
          Row(
            children: [
              _timeSegment(label: 'DAYS', value: days.toString().padLeft(2, '0'), isDark: isDark),
              _separator(isDark),
              _timeSegment(label: 'HOURS', value: hours.toString().padLeft(2, '0'), isDark: isDark),
              _separator(isDark),
              _timeSegment(label: 'MINS', value: minutes.toString().padLeft(2, '0'), isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _separator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        ':',
        style: TextStyle(
          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _timeSegment({required String label, required String value, required bool isDark}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
            borderRadius: AppTokens.borderSmall,
            border: Border.all(
              color: isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder,
              width: 0.8,
            ),
          ),
          child: Text(
            value,
            style: AppTypography.metricSmall(isDark: isDark).copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.white : AppColors.textPrimaryLight,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.label(isDark: isDark).copyWith(fontSize: 8.5),
        ),
      ],
    );
  }
}
