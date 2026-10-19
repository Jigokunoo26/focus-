import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../data/providers/database_provider.dart';
import '../../../domain/models/task_item.dart';
import 'task_create_dialog.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _filter = 'all'; // 'all', 'active', 'completed', 'urgent'
  String _sortMode = 'priority'; // 'priority', 'due_date', 'title'
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(taskListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Tasks & Deadlines',
          style: AppTypography.titleLarge(isDark: isDark),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const TaskCreateDialog(),
          );
        },
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // Search & Filter header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space16,
                    vertical: AppTokens.space8,
                  ),
            child: Column(
              children: [
                // Search Field
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: AppTypography.body(isDark: isDark),
                    decoration: InputDecoration(
                      icon: Icon(
                        LucideIcons.search,
                        size: 18,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      hintText: 'Search tasks...',
                      hintStyle: AppTypography.body(isDark: isDark).copyWith(
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space12),

                // Filter Pills & Sort Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip('all', 'All', isDark),
                            const SizedBox(width: AppTokens.space8),
                            _filterChip('active', 'Active', isDark),
                            const SizedBox(width: AppTokens.space8),
                            _filterChip('urgent', 'Urgent', isDark),
                            const SizedBox(width: AppTokens.space8),
                            _filterChip('completed', 'Done', isDark),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space8),
                    PopupMenuButton<String>(
                      initialValue: _sortMode,
                      icon: Icon(
                        LucideIcons.arrowUpDown,
                        size: 16,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      onSelected: (val) => setState(() => _sortMode = val),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'priority', child: Text('Sort by Priority')),
                        const PopupMenuItem(value: 'due_date', child: Text('Sort by Due Date')),
                        const PopupMenuItem(value: 'title', child: Text('Sort by Title')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Task List
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                final topLevelFiltered = tasks.where((t) {
                  if (t.parentTaskId != null) return false;

                  if (_searchQuery.isNotEmpty &&
                      !t.title.toLowerCase().contains(_searchQuery) &&
                      !t.description.toLowerCase().contains(_searchQuery)) {
                    return false;
                  }

                  switch (_filter) {
                    case 'active':
                      return !t.isCompleted;
                    case 'completed':
                      return t.isCompleted;
                    case 'urgent':
                      return t.priority == TaskPriority.high && !t.isCompleted;
                    case 'all':
                    default:
                      return true;
                  }
                }).toList();

                topLevelFiltered.sort((a, b) {
                  switch (_sortMode) {
                    case 'due_date':
                      if (a.dueAt == null && b.dueAt == null) return 0;
                      if (a.dueAt == null) return 1;
                      if (b.dueAt == null) return -1;
                      return a.dueAt!.compareTo(b.dueAt!);
                    case 'title':
                      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
                    case 'priority':
                    default:
                      final pDiff = b.priority.value.compareTo(a.priority.value);
                      if (pDiff != 0) return pDiff;
                      return b.createdAt.compareTo(a.createdAt);
                  }
                });

                if (topLevelFiltered.isEmpty) {
                  return EmptyState(
                    icon: LucideIcons.inbox,
                    title: 'No tasks found',
                    subtitle: 'Create a task or clear filters.',
                    actionLabel: 'New Task',
                    onAction: () {
                      showDialog(
                        context: context,
                        builder: (_) => const TaskCreateDialog(),
                      );
                    },
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space20,
                    vertical: AppTokens.space12,
                  ),
                  itemCount: topLevelFiltered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppTokens.space8),
                  itemBuilder: (context, index) {
                    final task = topLevelFiltered[index];
                    return _TaskCard(task: task, allTasks: tasks, isDark: isDark);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    ),
  ),
),
);
  }

  Widget _filterChip(String key, String label, bool isDark) {
    final isSelected = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: AnimatedContainer(
        duration: AppTokens.durationFast,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.white : AppColors.textPrimaryLight)
              : (isDark ? AppColors.darkCardHover : AppColors.lightCardHover),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? (isDark ? AppColors.darkBackground : AppColors.white)
                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends ConsumerStatefulWidget {
  final TaskItem task;
  final List<TaskItem> allTasks;
  final bool isDark;

  const _TaskCard({
    required this.task,
    required this.allTasks,
    required this.isDark,
  });

  @override
  ConsumerState<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<_TaskCard> {
  bool _isExpanded = false;

  void _showAddSubtaskDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? AppColors.darkCard : AppColors.lightCard,
        title: Text('Add Subtask', style: AppTypography.titleMedium(isDark: widget.isDark)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTypography.body(isDark: widget.isDark),
          decoration: InputDecoration(
            hintText: 'Subtask title...',
            hintStyle: AppTypography.body(isDark: widget.isDark).copyWith(
              color: widget.isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isNotEmpty) {
                ref.read(taskListProvider.notifier).createSubtask(
                      parentTaskId: widget.task.id,
                      title: title,
                    );
                setState(() => _isExpanded = true);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = widget.isDark;

    final subtasks = widget.allTasks.where((t) => t.parentTaskId == task.id).toList();
    final completedSubtasks = subtasks.where((t) => t.isCompleted).length;

    Color priorityColor;
    switch (task.priority) {
      case TaskPriority.high:
        priorityColor = AppColors.urgent;
        break;
      case TaskPriority.medium:
        priorityColor = AppColors.warning;
        break;
      case TaskPriority.low:
      case TaskPriority.none:
        priorityColor = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
        break;
    }

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.urgent.withValues(alpha: 0.85),
          borderRadius: AppTokens.borderMedium,
        ),
        child: const Icon(LucideIcons.trash2, color: AppColors.white, size: 20),
      ),
      onDismissed: (_) {
        ref.read(taskListProvider.notifier).deleteTask(task.id);
      },
      child: GlassCard(
        padding: const EdgeInsets.all(AppTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                GestureDetector(
                  onTap: () => ref.read(taskListProvider.notifier).toggleComplete(task.id),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: task.isCompleted
                          ? AppColors.accent
                          : (isDark ? AppColors.darkGlassBackground : AppColors.lightGlassBackground),
                      border: Border.all(
                        color: task.isCompleted
                            ? AppColors.accent
                            : (isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder),
                        width: 1.5,
                      ),
                    ),
                    child: task.isCompleted
                        ? const Icon(LucideIcons.check, size: 13, color: AppColors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: AppTokens.space12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: AppTypography.titleMedium(isDark: isDark).copyWith(
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          color: task.isCompleted
                              ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          style: AppTypography.bodySmall(isDark: isDark),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppTokens.space8),
                      Row(
                        children: [
                          // Priority Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: priorityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: priorityColor.withValues(alpha: 0.3), width: 0.8),
                            ),
                            child: Text(
                              task.priority.label.toUpperCase(),
                              style: TextStyle(
                                color: priorityColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (task.dueAt != null) ...[
                            const SizedBox(width: AppTokens.space8),
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.calendar,
                                  size: 12,
                                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MMM d').format(task.dueAt!),
                                  style: AppTypography.label(isDark: isDark),
                                ),
                              ],
                            ),
                          ],
                          if (subtasks.isNotEmpty) ...[
                            const SizedBox(width: AppTokens.space8),
                            GestureDetector(
                              onTap: () => setState(() => _isExpanded = !_isExpanded),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.listTodo,
                                      size: 11,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$completedSubtasks/${subtasks.length}',
                                      style: AppTypography.label(isDark: isDark).copyWith(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Quick Add Subtask Button
                          GestureDetector(
                            onTap: _showAddSubtaskDialog,
                            child: Icon(
                              LucideIcons.plus,
                              size: 14,
                              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                            ),
                          ),
                          if (subtasks.isNotEmpty) ...[
                            const SizedBox(width: AppTokens.space6),
                            GestureDetector(
                              onTap: () => setState(() => _isExpanded = !_isExpanded),
                              child: Icon(
                                _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                                size: 14,
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

            // Subtask Progress Bar (if subtasks exist)
            if (subtasks.isNotEmpty) ...[
              const SizedBox(height: AppTokens.space12),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: completedSubtasks / subtasks.length,
                  backgroundColor: isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completedSubtasks == subtasks.length ? AppColors.success : AppColors.accent,
                  ),
                  minHeight: 2,
                ),
              ),
            ],

            // Expandable Subtask Checklist
            if (_isExpanded && subtasks.isNotEmpty) ...[
              const SizedBox(height: AppTokens.space12),
              Container(
                padding: const EdgeInsets.only(left: 32, top: 4),
                child: Column(
                  children: subtasks.map((sub) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => ref.read(taskListProvider.notifier).toggleComplete(sub.id),
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: sub.isCompleted ? AppColors.accent : Colors.transparent,
                                border: Border.all(
                                  color: sub.isCompleted
                                      ? AppColors.accent
                                      : (isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder),
                                  width: 1.2,
                                ),
                              ),
                              child: sub.isCompleted
                                  ? const Icon(LucideIcons.check, size: 10, color: AppColors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppTokens.space8),
                          Expanded(
                            child: Text(
                              sub.title,
                              style: AppTypography.bodySmall(isDark: isDark).copyWith(
                                decoration: sub.isCompleted ? TextDecoration.lineThrough : null,
                                color: sub.isCompleted
                                    ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
                                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => ref.read(taskListProvider.notifier).deleteTask(sub.id),
                            child: Icon(
                              LucideIcons.x,
                              size: 12,
                              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
