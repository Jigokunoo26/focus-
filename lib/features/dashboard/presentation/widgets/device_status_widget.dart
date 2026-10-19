import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widget_shell.dart';

class DeviceStatusWidget extends StatelessWidget {
  final VoidCallback? onOpenHealth;

  const DeviceStatusWidget({super.key, this.onOpenHealth});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final platformName = kIsWeb ? 'Web Engine' : (Platform.isWindows ? 'Windows Desktop' : 'Android OS');

    return WidgetShell(
      title: 'System & Security',
      icon: LucideIcons.shieldCheck,
      statusTag: 'SECURE',
      statusColor: AppColors.success,
      onTap: onOpenHealth,
      child: Column(
        children: [
          _StatusRow(
            icon: LucideIcons.hardDrive,
            label: 'Local SQLite DB',
            status: 'Encrypted & Durable',
            isDark: isDark,
            statusColor: AppColors.success,
          ),
          const SizedBox(height: AppTokens.space8),
          _StatusRow(
            icon: LucideIcons.cloudOff,
            label: 'Cloud Sync',
            status: '0 KB (Local Only)',
            isDark: isDark,
            statusColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: AppTokens.space8),
          _StatusRow(
            icon: LucideIcons.cpu,
            label: 'Platform Host',
            status: platformName,
            isDark: isDark,
            statusColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final bool isDark;
  final Color statusColor;

  const _StatusRow({
    required this.icon,
    required this.label,
    required this.status,
    required this.isDark,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
            const SizedBox(width: AppTokens.space8),
            Text(
              label,
              style: AppTypography.bodySmall(isDark: isDark),
            ),
          ],
        ),
        Text(
          status,
          style: AppTypography.label(isDark: isDark).copyWith(
            color: statusColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
