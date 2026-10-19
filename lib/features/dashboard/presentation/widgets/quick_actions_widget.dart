import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_card.dart';

class QuickActionsWidget extends StatelessWidget {
  final VoidCallback onAddTask;
  final VoidCallback onStartFocus;
  final VoidCallback onLogHabit;
  final VoidCallback onVoiceCapture;

  const QuickActionsWidget({
    super.key,
    required this.onAddTask,
    required this.onStartFocus,
    required this.onLogHabit,
    required this.onVoiceCapture,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space12,
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: LucideIcons.plus,
              label: 'Add Task',
              onTap: onAddTask,
              isDark: isDark,
              isPrimary: true,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: LucideIcons.timer,
              label: 'Focus',
              onTap: onStartFocus,
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: LucideIcons.checkSquare,
              label: 'Habits',
              onTap: onLogHabit,
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: LucideIcons.mic,
              label: 'Dictate',
              onTap: onVoiceCapture,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.isPrimary = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isPrimary
        ? AppColors.accent
        : (_isHovered
            ? (widget.isDark ? AppColors.darkCardHover : AppColors.lightCardHover)
            : (widget.isDark ? AppColors.darkGlassBackground : AppColors.lightGlassBackground));

    final fg = widget.isPrimary
        ? AppColors.white
        : (widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    final border = widget.isPrimary
        ? Colors.transparent
        : (widget.isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.94 : 1.0,
          duration: AppTokens.durationFast,
          curve: AppTokens.curveStandard,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppTokens.durationFast,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: AppTokens.borderSmall,
                  border: Border.all(color: border, width: 1),
                ),
                child: Icon(widget.icon, size: 20, color: fg),
              ),
              const SizedBox(height: AppTokens.space6),
              Text(
                widget.label,
                style: AppTypography.bodySmall(isDark: widget.isDark).copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
