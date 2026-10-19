import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import 'glass_card.dart';

/// A standardized shell container for Personal OS dashboard widgets.
class WidgetShell extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry? contentPadding;
  final VoidCallback? onTap;
  final String? statusTag;
  final Color? statusColor;
  final double? height;

  const WidgetShell({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
    required this.child,
    this.contentPadding,
    this.onTap,
    this.statusTag,
    this.statusColor,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Row
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  const SizedBox(width: AppTokens.space8),
                ],
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: AppTypography.label(isDark: isDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (statusTag != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (statusColor ?? AppColors.accent).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: (statusColor ?? AppColors.accent).withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      statusTag!,
                      style: AppTypography.label(isDark: isDark).copyWith(
                        color: statusColor ?? AppColors.accent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.space6),
                ],
                ?trailing,
              ],
            ),
            const SizedBox(height: AppTokens.space12),

            // Content Body
            Expanded(
              flex: height != null ? 1 : 0,
              child: Padding(
                padding: contentPadding ?? EdgeInsets.zero,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
