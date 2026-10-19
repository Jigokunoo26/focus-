import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// A premium frosted-glass card inspired by Nothing OS minimalism and Apple glass polish.
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double blurSigma;
  final bool enableHover;
  final bool showHighlight;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.blurSigma = AppTokens.blurStandard,
    this.enableHover = true,
    this.showHighlight = true,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = widget.borderRadius ?? AppTokens.borderMedium;

    final defaultBg = isDark
        ? (_isHovered ? AppColors.darkCardHover : AppColors.darkGlassBackground)
        : (_isHovered ? AppColors.lightCardHover : AppColors.lightGlassBackground);

    final defaultBorder = isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder;

    return MouseRegion(
      onEnter: (_) {
        if (widget.enableHover && widget.onTap != null) {
          setState(() => _isHovered = true);
        }
      },
      onExit: (_) {
        if (widget.enableHover && widget.onTap != null) {
          setState(() => _isHovered = false);
        }
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.onTap != null) {
            setState(() => _isPressed = true);
          }
        },
        onTapUp: (_) {
          if (widget.onTap != null) {
            setState(() => _isPressed = false);
          }
        },
        onTapCancel: () {
          if (widget.onTap != null) {
            setState(() => _isPressed = false);
          }
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1.0,
          duration: AppTokens.durationFast,
          curve: AppTokens.curveStandard,
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: widget.blurSigma,
                sigmaY: widget.blurSigma,
              ),
              child: AnimatedContainer(
                duration: AppTokens.durationFast,
                padding: widget.padding ?? const EdgeInsets.all(AppTokens.space16),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? defaultBg,
                  borderRadius: radius,
                  border: Border.all(
                    color: widget.borderColor ?? (_isHovered ? defaultBorder.withValues(alpha: 0.35) : defaultBorder),
                    width: 1.0,
                  ),
                  gradient: widget.showHighlight
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            isDark ? AppColors.darkGlassHighlight : AppColors.lightGlassHighlight,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45],
                        )
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
