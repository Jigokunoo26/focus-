import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widget_shell.dart';
import '../../../../data/providers/database_provider.dart';

class AgendaGlanceWidget extends ConsumerWidget {
  final VoidCallback onOpenCalendar;

  const AgendaGlanceWidget({super.key, required this.onOpenCalendar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventsAsync = ref.watch(eventListProvider);

    return WidgetShell(
      title: "Today's Agenda",
      icon: LucideIcons.calendar,
      statusTag: 'TIMELINE',
      onTap: onOpenCalendar,
      child: eventsAsync.when(
        data: (events) {
          final now = DateTime.now();
          final todayEvents = events.where((e) {
            final start = e.startsAt.toLocal();
            return start.year == now.year && start.month == now.month && start.day == now.day;
          }).toList();

          if (todayEvents.isEmpty) {
            return Row(
              children: [
                Icon(
                  LucideIcons.calendarCheck,
                  size: 20,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                ),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Text(
                    'No scheduled events today. Focus on priority tasks.',
                    style: AppTypography.bodySmall(isDark: isDark),
                  ),
                ),
              ],
            );
          }

          // Show top 2 upcoming events
          final displayEvents = todayEvents.take(2).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final event in displayEvents) ...[
                _buildEventItem(event, isDark),
                if (event != displayEvents.last) const SizedBox(height: AppTokens.space8),
              ],
            ],
          );
        },
        loading: () => const Center(
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => Text('Schedule unavailable', style: AppTypography.bodySmall(isDark: isDark)),
      ),
    );
  }

  Widget _buildEventItem(dynamic event, bool isDark) {
    Color cardColor;
    try {
      cardColor = Color(int.parse(event.colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      cardColor = AppColors.accent;
    }

    final timeString = event.isAllDay
        ? 'All Day'
        : '${DateFormat('HH:mm').format(event.startsAt)} - ${DateFormat('HH:mm').format(event.endsAt)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
        borderRadius: AppTokens.borderSmall,
        border: Border.all(
          color: isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTokens.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: AppTypography.titleSmall(isDark: isDark).copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      timeString,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10.5,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    if (event.location != null && event.location!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${event.location!}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
