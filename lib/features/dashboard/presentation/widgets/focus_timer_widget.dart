import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../../../core/widgets/widget_shell.dart';

class FocusTimerWidget extends StatefulWidget {
  final VoidCallback? onExpand;

  const FocusTimerWidget({super.key, this.onExpand});

  @override
  State<FocusTimerWidget> createState() => _FocusTimerWidgetState();
}

class _FocusTimerWidgetState extends State<FocusTimerWidget> {
  static const int totalSeconds = 25 * 60;
  int _remainingSeconds = totalSeconds;
  bool _isRunning = false;
  Timer? _timer;

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          timer.cancel();
          setState(() {
            _isRunning = false;
            _remainingSeconds = totalSeconds;
          });
        }
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = totalSeconds;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    final progress = 1.0 - (_remainingSeconds / totalSeconds);

    return WidgetShell(
      title: 'Focus Session',
      icon: LucideIcons.timer,
      statusTag: _isRunning ? 'ACTIVE' : 'IDLE',
      statusColor: _isRunning ? AppColors.accent : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
      trailing: IconButton(
        icon: const Icon(LucideIcons.rotateCcw, size: 16),
        onPressed: _resetTimer,
        tooltip: 'Reset Timer',
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Monospace Countdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$minutes:$seconds',
                style: AppTypography.metricLarge(isDark: isDark),
              ),
              const SizedBox(height: 2),
              Text(
                '25 min Deep Work Block',
                style: AppTypography.bodySmall(isDark: isDark),
              ),
            ],
          ),

          // Play / Pause Button with Progress Ring
          ProgressRing(
            progress: progress,
            size: 52,
            strokeWidth: 3.5,
            color: AppColors.accent,
            center: GestureDetector(
              onTap: _toggleTimer,
              child: AnimatedContainer(
                duration: AppTokens.durationFast,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRunning ? AppColors.accent : (isDark ? AppColors.white : AppColors.textPrimaryLight),
                ),
                child: Icon(
                  _isRunning ? LucideIcons.pause : LucideIcons.play,
                  size: 16,
                  color: _isRunning ? AppColors.white : (isDark ? AppColors.darkBackground : AppColors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
