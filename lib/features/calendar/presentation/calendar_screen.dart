import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/minimal_button.dart';
import '../../../data/providers/database_provider.dart';
import '../../../domain/models/event_item.dart';
import '../../../domain/models/task_item.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.accent,
                    surface: AppColors.darkCard,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.accent,
                  ),
                ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _showCreateEventDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateEventDialog(
        initialDate: _selectedDate,
        onEventCreated: (title, desc, startsAt, endsAt, isAllDay, location, colorHex) {
          ref.read(eventListProvider.notifier).createEvent(
                title: title,
                description: desc,
                startsAt: startsAt,
                endsAt: endsAt,
                isAllDay: isAllDay,
                location: location,
                colorHex: colorHex,
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventsAsync = ref.watch(eventListProvider);
    final tasksAsync = ref.watch(taskListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        titleSpacing: AppTokens.space20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(_selectedDate).toUpperCase(),
              style: AppTypography.label(isDark: isDark).copyWith(
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              DateFormat('EEEE, d MMM').format(_selectedDate),
              style: AppTypography.titleLarge(isDark: isDark).copyWith(fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.calendarDays, size: 18),
            tooltip: 'Pick Date',
            onPressed: _pickDate,
          ),
          IconButton(
            icon: const Icon(LucideIcons.rotateCcw, size: 18),
            tooltip: 'Today',
            onPressed: _goToToday,
          ),
          const SizedBox(width: AppTokens.space8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        tooltip: 'Add Event',
        onPressed: _showCreateEventDialog,
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // 7-day horizontal strip
                _buildDateStrip(isDark),
                const SizedBox(height: AppTokens.space8),

                // Agenda Timeline
                Expanded(
                  child: eventsAsync.when(
                    data: (events) {
                      final allTasks = tasksAsync.value ?? [];

                      // Filter events for selected date
                      final dayEvents = events.where((e) {
                        final eStart = e.startsAt.toLocal();
                        return eStart.year == _selectedDate.year &&
                            eStart.month == _selectedDate.month &&
                            eStart.day == _selectedDate.day;
                      }).toList();

                      // Filter tasks with due dates on selected date
                      final dayTasks = allTasks.where((t) {
                        if (t.dueAt == null) return false;
                        final due = t.dueAt!.toLocal();
                        return due.year == _selectedDate.year &&
                            due.month == _selectedDate.month &&
                            due.day == _selectedDate.day;
                      }).toList();

                      return _buildTimelineView(
                        isDark: isDark,
                        events: dayEvents,
                        tasks: dayTasks,
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Text('Error loading calendar: $err', style: AppTypography.body(isDark: isDark)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateStrip(bool isDark) {
    // Generate 7 days centered on selected date
    final dates = List.generate(7, (i) {
      return _selectedDate.subtract(const Duration(days: 3)).add(Duration(days: i));
    });

    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space8, vertical: AppTokens.space8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(LucideIcons.chevronLeft, size: 16),
              onPressed: _previousDay,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: AppTokens.space4),
            ...dates.map((d) {
              final isSelected = d.year == _selectedDate.year &&
                  d.month == _selectedDate.month &&
                  d.day == _selectedDate.day;
              final isToday = d.year == now.year && d.month == now.month && d.day == now.day;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = DateTime(d.year, d.month, d.day);
                    });
                  },
                  child: AnimatedContainer(
                    duration: AppTokens.durationFast,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? AppColors.white : AppColors.textPrimaryLight)
                          : (isDark ? AppColors.darkCard : AppColors.lightCard),
                      borderRadius: AppTokens.borderMedium,
                      border: Border.all(
                        color: isToday && !isSelected
                            ? AppColors.accent
                            : (isSelected
                                ? Colors.transparent
                                : (isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder)),
                        width: isToday && !isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('E').format(d).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? (isDark ? AppColors.darkBackground : AppColors.white)
                                : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: isSelected
                                ? (isDark ? AppColors.darkBackground : AppColors.white)
                                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: AppTokens.space4),
            IconButton(
              icon: const Icon(LucideIcons.chevronRight, size: 16),
              onPressed: _nextDay,
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineView({
    required bool isDark,
    required List<EventItem> events,
    required List<TaskItem> tasks,
  }) {
    if (events.isEmpty && tasks.isEmpty) {
      return EmptyState(
        icon: LucideIcons.calendar,
        title: 'Clear Schedule',
        subtitle: 'No events or scheduled tasks for ${DateFormat('MMMM d').format(_selectedDate)}.',
        actionLabel: 'Schedule Event',
        onAction: _showCreateEventDialog,
      );
    }

    final allDayEvents = events.where((e) => e.isAllDay).toList();
    final timedEvents = events.where((e) => !e.isAllDay).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space20, vertical: AppTokens.space12),
      children: [
        // All Day Events Section
        if (allDayEvents.isNotEmpty) ...[
          Text('ALL-DAY EVENTS', style: AppTypography.label(isDark: isDark)),
          const SizedBox(height: AppTokens.space8),
          for (final event in allDayEvents) ...[
            _buildEventCard(event, isDark),
            const SizedBox(height: AppTokens.space8),
          ],
          const SizedBox(height: AppTokens.space16),
        ],

        // Hour Timeline (07:00 to 22:00)
        Text('AGENDA TIMELINE', style: AppTypography.label(isDark: isDark)),
        const SizedBox(height: AppTokens.space12),

        for (int hour = 7; hour <= 22; hour++) ...[
          _buildHourRow(
            hour: hour,
            isDark: isDark,
            events: timedEvents.where((e) => e.startsAt.hour == hour).toList(),
            tasks: tasks.where((t) => t.dueAt?.hour == hour).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildHourRow({
    required int hour,
    required bool isDark,
    required List<EventItem> events,
    required List<TaskItem> tasks,
  }) {
    final hourLabel = '${hour.toString().padLeft(2, '0')}:00';
    final hasItems = events.isNotEmpty || tasks.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time label
          SizedBox(
            width: 52,
            child: Text(
              hourLabel,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.space8),

          // Content Column
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: (isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder)
                        .withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
              ),
              child: hasItems
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final event in events) ...[
                          _buildEventCard(event, isDark),
                          const SizedBox(height: 6),
                        ],
                        for (final task in tasks) ...[
                          _buildTaskCard(task, isDark),
                          const SizedBox(height: 6),
                        ],
                      ],
                    )
                  : const SizedBox(height: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(EventItem event, bool isDark) {
    Color cardColor;
    try {
      cardColor = Color(int.parse(event.colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      cardColor = AppColors.accent;
    }

    final timeString = event.isAllDay
        ? 'All Day'
        : '${DateFormat('HH:mm').format(event.startsAt)} - ${DateFormat('HH:mm').format(event.endsAt)}';

    return Dismissible(
      key: Key('event-${event.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.urgent.withValues(alpha: 0.8),
          borderRadius: AppTokens.borderMedium,
        ),
        child: const Icon(LucideIcons.trash2, color: AppColors.white, size: 18),
      ),
      onDismissed: (_) {
        ref.read(eventListProvider.notifier).deleteEvent(event.id);
      },
      child: GlassCard(
        padding: const EdgeInsets.all(AppTokens.space12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 38,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.titleMedium(isDark: isDark).copyWith(fontSize: 14),
                  ),
                  if (event.description != null && event.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      event.description!,
                      style: AppTypography.bodySmall(isDark: isDark).copyWith(fontSize: 11.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.clock,
                        size: 11,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeString,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      if (event.location != null && event.location!.isNotEmpty) ...[
                        const SizedBox(width: AppTokens.space12),
                        Icon(
                          LucideIcons.mapPin,
                          size: 11,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          event.location!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
      ),
    );
  }

  Widget _buildTaskCard(TaskItem task, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkCardHover : AppColors.lightCardHover),
        borderRadius: AppTokens.borderSmall,
        border: Border.all(
          color: isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              ref.read(taskListProvider.notifier).toggleTaskCompletion(task.id);
            },
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.isCompleted ? AppColors.accent : AppColors.textTertiaryDark,
                  width: 1.5,
                ),
                color: task.isCompleted ? AppColors.accent : Colors.transparent,
              ),
              child: task.isCompleted
                  ? const Icon(LucideIcons.check, size: 12, color: AppColors.white)
                  : null,
            ),
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 13,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted
                    ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'TASK',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateEventDialog extends StatefulWidget {
  final DateTime initialDate;
  final void Function(
    String title,
    String? description,
    DateTime startsAt,
    DateTime endsAt,
    bool isAllDay,
    String? location,
    String colorHex,
  ) onEventCreated;

  const _CreateEventDialog({
    required this.initialDate,
    required this.onEventCreated,
  });

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locController = TextEditingController();

  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _isAllDay = false;
  final String _colorHex = '#FF3B30';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
    _endTime = TimeOfDay(hour: (now.hour + 2) % 24, minute: 0);
  }

  void _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          if (_endTime.hour < _startTime.hour) {
            _endTime = TimeOfDay(hour: (_startTime.hour + 1) % 24, minute: 0);
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SCHEDULE EVENT', style: AppTypography.label(isDark: isDark)),
              const SizedBox(height: AppTokens.space16),
              TextField(
                controller: _titleController,
                autofocus: true,
                style: AppTypography.titleMedium(isDark: isDark),
                decoration: InputDecoration(
                  hintText: 'Event Title (e.g. Sprint Planning)',
                  hintStyle: AppTypography.titleMedium(isDark: isDark).copyWith(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: AppTokens.space12),
              TextField(
                controller: _descController,
                maxLines: 2,
                style: AppTypography.body(isDark: isDark),
                decoration: InputDecoration(
                  hintText: 'Notes or agenda details',
                  hintStyle: AppTypography.body(isDark: isDark).copyWith(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: AppTokens.space12),
              TextField(
                controller: _locController,
                style: AppTypography.body(isDark: isDark),
                decoration: InputDecoration(
                  prefixIcon: const Icon(LucideIcons.mapPin, size: 16),
                  hintText: 'Location (optional)',
                  hintStyle: AppTypography.body(isDark: isDark).copyWith(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: AppTokens.space16),

              // All day switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('All Day Event', style: AppTypography.body(isDark: isDark)),
                  Switch.adaptive(
                    value: _isAllDay,
                    activeTrackColor: AppColors.accent,
                    onChanged: (val) => setState(() => _isAllDay = val),
                  ),
                ],
              ),

              if (!_isAllDay) ...[
                const SizedBox(height: AppTokens.space12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(true),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
                            borderRadius: AppTokens.borderSmall,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('START', style: AppTypography.label(isDark: isDark)),
                              const SizedBox(height: 2),
                              Text(
                                _startTime.format(context),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _pickTime(false),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
                            borderRadius: AppTokens.borderSmall,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('END', style: AppTypography.label(isDark: isDark)),
                              const SizedBox(height: 2),
                              Text(
                                _endTime.format(context),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppTokens.space20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MinimalButton(
                    label: 'Cancel',
                    variant: MinimalButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppTokens.space12),
                  MinimalButton(
                    label: 'Schedule',
                    variant: MinimalButtonVariant.accent,
                    onPressed: () {
                      final title = _titleController.text.trim();
                      if (title.isEmpty) return;

                      final base = widget.initialDate;
                      final start = DateTime(
                        base.year,
                        base.month,
                        base.day,
                        _isAllDay ? 0 : _startTime.hour,
                        _isAllDay ? 0 : _startTime.minute,
                      );
                      final end = DateTime(
                        base.year,
                        base.month,
                        base.day,
                        _isAllDay ? 23 : _endTime.hour,
                        _isAllDay ? 59 : _endTime.minute,
                      );

                      widget.onEventCreated(
                        title,
                        _descController.text.trim().isEmpty ? null : _descController.text.trim(),
                        start,
                        end,
                        _isAllDay,
                        _locController.text.trim().isEmpty ? null : _locController.text.trim(),
                        _colorHex,
                      );
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
