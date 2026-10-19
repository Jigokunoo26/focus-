import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

enum MinimalButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  accent,
}

class MinimalButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final MinimalButtonVariant variant;
  final bool isFullWidth;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const MinimalButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = MinimalButtonVariant.primary,
    this.isFullWidth = false,
    this.height = 42.0,
    this.padding,
  });

  @override
  State<MinimalButton> createState() => _MinimalButtonState();
}

class _MinimalButtonState extends State<MinimalButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = widget.onPressed == null;

    Color bg;
    Color fg;
    Color border;

    switch (widget.variant) {
      case MinimalButtonVariant.primary:
        bg = isDark
            ? (_isHovered ? AppColors.white.withValues(alpha: 0.9) : AppColors.white)
            : (_isHovered ? AppColors.textPrimaryLight.withValues(alpha: 0.9) : AppColors.textPrimaryLight);
        fg = isDark ? AppColors.darkBackground : AppColors.white;
        border = Colors.transparent;
        break;

      case MinimalButtonVariant.secondary:
        bg = isDark
            ? (_isHovered ? AppColors.darkCardHover : AppColors.darkCard)
            : (_isHovered ? AppColors.lightCardHover : AppColors.lightCard);
        fg = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        border = isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder;
        break;

      case MinimalButtonVariant.outline:
        bg = Colors.transparent;
        fg = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        border = isDark
            ? (_isHovered ? AppColors.white.withValues(alpha: 0.4) : AppColors.darkGlassBorder)
            : (_isHovered ? AppColors.textPrimaryLight.withValues(alpha: 0.4) : AppColors.lightGlassBorder);
        break;

      case MinimalButtonVariant.ghost:
        bg = _isHovered
            ? (isDark ? AppColors.darkGlassBackground : AppColors.lightGlassBackground)
            : Colors.transparent;
        fg = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        border = Colors.transparent;
        break;

      case MinimalButtonVariant.accent:
        bg = _isHovered ? AppColors.accent.withValues(alpha: 0.9) : AppColors.accent;
        fg = AppColors.white;
        border = Colors.transparent;
        break;
    }

    if (isDisabled) {
      bg = bg.withValues(alpha: 0.3);
      fg = fg.withValues(alpha: 0.4);
      border = border.withValues(alpha: 0.2);
    }

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 16, color: fg),
          const SizedBox(width: AppTokens.space8),
        ],
        Text(
          widget.label,
          style: AppTypography.button(isDark: isDark).copyWith(color: fg),
        ),
      ],
    );

    return MouseRegion(
      onEnter: (_) {
        if (!isDisabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (!isDisabled) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (!isDisabled) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (!isDisabled) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (!isDisabled) setState(() => _isPressed = false);
        },
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: AppTokens.durationFast,
          curve: AppTokens.curveStandard,
          child: AnimatedContainer(
            duration: AppTokens.durationFast,
            height: widget.height,
            padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: AppTokens.space16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: AppTokens.borderSmall,
              border: Border.all(color: border, width: 1),
            ),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}
