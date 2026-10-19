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
import '../../../core/widgets/progress_ring.dart';
import '../../../data/providers/database_provider.dart';
import '../../../domain/models/project_item.dart';
import '../../../domain/models/task_item.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime? _selectedDeadline;

  void _showAddProjectDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassCard(
                padding: const EdgeInsets.all(AppTokens.space24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CREATE NEW PROJECT', style: AppTypography.label(isDark: isDark)),
                      const SizedBox(height: AppTokens.space16),
                      TextField(
                        controller: _nameController,
                        autofocus: true,
                        style: AppTypography.titleMedium(isDark: isDark),
                        decoration: InputDecoration(
                          hintText: 'Project Name (e.g. Smart Attendance)',
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
                          hintText: 'Project scope, goals, and milestones',
                          hintStyle: AppTypography.body(isDark: isDark).copyWith(
                            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: AppTokens.space16),
                      Text('TARGET DEADLINE', style: AppTypography.label(isDark: isDark)),
                      const SizedBox(height: AppTokens.space8),
                      Row(
                        children: [
                          _deadlineChip(
                            label: '2 Weeks',
                            days: 14,
                            isSelected: _selectedDeadline != null &&
                                _selectedDeadline!.difference(DateTime.now()).inDays == 14,
                            onTap: () => setDialogState(
                              () => _selectedDeadline = DateTime.now().add(const Duration(days: 14)),
                            ),
                            isDark: isDark,
                          ),
                          const SizedBox(width: AppTokens.space8),
                          _deadlineChip(
                            label: '1 Month',
                            days: 30,
                            isSelected: _selectedDeadline != null &&
                                _selectedDeadline!.difference(DateTime.now()).inDays == 30,
                            onTap: () => setDialogState(
                              () => _selectedDeadline = DateTime.now().add(const Duration(days: 30)),
                            ),
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space24),
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
                            label: 'Create Project',
                            variant: MinimalButtonVariant.accent,
                            onPressed: () {
                              final name = _nameController.text.trim();
                              if (name.isNotEmpty) {
                                ref.read(projectListProvider.notifier).addProject(
                                      name: name,
                                      description: _descController.text.trim(),
                                      deadline: _selectedDeadline,
                                    );
                                _nameController.clear();
                                _descController.clear();
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _deadlineChip({
    required String label,
    required int days,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.white : AppColors.textPrimaryLight)
              : (isDark ? AppColors.darkCardHover : AppColors.lightCardHover),
          borderRadius: BorderRadius.circular(6),
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

  void _showAddTaskForProject(String projectId, String projectName) {
    final titleController = TextEditingController();
    TaskPriority priority = TaskPriority.medium;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: GlassCard(
                padding: const EdgeInsets.all(AppTokens.space24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NEW MILESTONE / TASK', style: AppTypography.label(isDark: isDark)),
                    const SizedBox(height: 4),
                    Text(
                      'For: $projectName',
                      style: AppTypography.bodySmall(isDark: isDark).copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      style: AppTypography.titleMedium(isDark: isDark),
                      decoration: InputDecoration(
                        hintText: 'Deliverable or milestone title',
                        hintStyle: AppTypography.titleMedium(isDark: isDark).copyWith(
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    Text('PRIORITY', style: AppTypography.label(isDark: isDark)),
                    const SizedBox(height: AppTokens.space8),
                    Row(
                      children: [
                        _priorityChoice('Low', TaskPriority.low, priority, isDark, () => setDialogState(() => priority = TaskPriority.low)),
                        const SizedBox(width: AppTokens.space8),
                        _priorityChoice('Med', TaskPriority.medium, priority, isDark, () => setDialogState(() => priority = TaskPriority.medium)),
                        const SizedBox(width: AppTokens.space8),
                        _priorityChoice('High', TaskPriority.high, priority, isDark, () => setDialogState(() => priority = TaskPriority.high)),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space24),
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
                          label: 'Add Deliverable',
                          variant: MinimalButtonVariant.accent,
                          onPressed: () {
                            final title = titleController.text.trim();
                            if (title.isNotEmpty) {
                              ref.read(taskListProvider.notifier).addTask(
                                    title: title,
                                    priority: priority,
                                    projectId: projectId,
                                  );
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _priorityChoice(
    String label,
    TaskPriority value,
    TaskPriority current,
    bool isDark,
    VoidCallback onTap,
  ) {
    final isSelected = value == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.white : AppColors.textPrimaryLight)
              : (isDark ? AppColors.darkCardHover : AppColors.lightCardHover),
          borderRadius: BorderRadius.circular(6),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectsAsync = ref.watch(projectListProvider);
    final tasksAsync = ref.watch(taskListProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text('Projects & Workflows', style: AppTypography.titleLarge(isDark: isDark)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        shape: const CircleBorder(),
        onPressed: _showAddProjectDialog,
        child: const Icon(LucideIcons.plus),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: projectsAsync.when(
              data: (projects) {
                if (projects.isEmpty) {
                  return EmptyState(
                    icon: LucideIcons.folder,
                    title: 'No Projects Yet',
                    subtitle: 'Organize your work, milestones, and deliverables.',
                    actionLabel: 'Create Project',
                    onAction: _showAddProjectDialog,
                  );
                }

                final allTasks = tasksAsync.value ?? [];

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space16,
                    vertical: AppTokens.space16,
                  ),
            itemCount: projects.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppTokens.space12),
            itemBuilder: (context, index) {
              final project = projects[index];
              final linkedTasks = allTasks.where((t) => t.projectId == project.id).toList();

              return Dismissible(
                key: Key(project.id),
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
                  ref.read(projectListProvider.notifier).deleteProject(project.id);
                },
                child: _ProjectCard(
                  project: project,
                  tasks: linkedTasks,
                  isDark: isDark,
                  onAddTask: () => _showAddTaskForProject(project.id, project.name),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    ),
  ),
),
);
  }
}

class _ProjectCard extends ConsumerStatefulWidget {
  final ProjectItem project;
  final List<TaskItem> tasks;
  final bool isDark;
  final VoidCallback onAddTask;

  const _ProjectCard({
    required this.project,
    required this.tasks,
    required this.isDark,
    required this.onAddTask,
  });

  @override
  ConsumerState<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends ConsumerState<_ProjectCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final completedTasks = widget.tasks.where((t) => t.isCompleted).length;
    final totalTasks = widget.tasks.length;
    final progress = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;
    final pct = (progress * 100).round();

    // Days remaining calculation
    String? deadlineLabel;
    Color? deadlineColor;
    if (widget.project.deadline != null) {
      final now = DateTime.now();
      final diff = widget.project.deadline!.difference(now).inDays;
      if (diff > 0) {
        deadlineLabel = '${diff}d left';
        deadlineColor = widget.isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
      } else if (diff == 0) {
        deadlineLabel = 'Due today';
        deadlineColor = AppColors.warning;
      } else {
        deadlineLabel = '${-diff}d overdue';
        deadlineColor = AppColors.urgent;
      }
    }

    return GlassCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row with progress ring, title, and expand button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                ProgressRing(
                  progress: progress,
                  size: 50,
                  strokeWidth: 4.5,
                  color: AppColors.accent,
                  center: Text(
                    '$pct%',
                    style: AppTypography.label(isDark: widget.isDark).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.project.name,
                        style: AppTypography.titleMedium(isDark: widget.isDark),
                      ),
                      if (widget.project.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.project.description,
                          style: AppTypography.bodySmall(isDark: widget.isDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppTokens.space6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$totalTasks deliverables ($completedTasks done)',
                              style: AppTypography.label(isDark: widget.isDark).copyWith(fontSize: 9.5),
                            ),
                          ),
                          if (widget.project.deadline != null) ...[
                            const SizedBox(width: AppTokens.space8),
                            Row(
                              children: [
                                Icon(
                                  LucideIcons.calendar,
                                  size: 11,
                                  color: widget.isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  DateFormat('MMM d').format(widget.project.deadline!),
                                  style: AppTypography.label(isDark: widget.isDark).copyWith(fontSize: 9.5),
                                ),
                              ],
                            ),
                          ],
                          if (deadlineLabel != null) ...[
                            const SizedBox(width: AppTokens.space8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (deadlineColor ?? AppColors.accent).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                deadlineLabel,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: deadlineColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 18,
                  color: widget.isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                ),
              ],
            ),
          ),

          // Expanded tasks & deliverables section
          if (_isExpanded) ...[
            const SizedBox(height: AppTokens.space16),
            Container(
              height: 0.8,
              color: (widget.isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder)
                  .withValues(alpha: 0.6),
            ),
            const SizedBox(height: AppTokens.space12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DELIVERABLES & MILESTONES',
                  style: AppTypography.label(isDark: widget.isDark).copyWith(fontSize: 10),
                ),
                GestureDetector(
                  onTap: widget.onAddTask,
                  child: Row(
                    children: [
                      const Icon(LucideIcons.plus, size: 12, color: AppColors.accent),
                      const SizedBox(width: 3),
                      Text(
                        'Add Milestone',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space8),

            if (widget.tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
                child: Center(
                  child: Text(
                    'No deliverables yet. Tap "+ Add Milestone" to plan milestones.',
                    style: AppTypography.bodySmall(isDark: widget.isDark),
                  ),
                ),
              )
            else
              for (final task in widget.tasks) ...[
                _buildTaskRow(task),
                const SizedBox(height: 6),
              ],
          ],
        ],
      ),
    );
  }

  Widget _buildTaskRow(TaskItem task) {
    Color priorityColor;
    switch (task.priority) {
      case TaskPriority.high:
        priorityColor = AppColors.urgent;
        break;
      case TaskPriority.medium:
        priorityColor = AppColors.warning;
        break;
      case TaskPriority.low:
      default:
        priorityColor = AppColors.info;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
        borderRadius: AppTokens.borderSmall,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              ref.read(taskListProvider.notifier).toggleTaskCompletion(task.id);
            },
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.isCompleted ? AppColors.accent : AppColors.textTertiaryDark,
                  width: 1.5,
                ),
                color: task.isCompleted ? AppColors.accent : Colors.transparent,
              ),
              child: task.isCompleted
                  ? const Icon(LucideIcons.check, size: 11, color: AppColors.white)
                  : null,
            ),
          ),
          const SizedBox(width: AppTokens.space10),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                fontSize: 12.5,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted
                    ? (widget.isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
                    : (widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              task.priority.name.toUpperCase(),
              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: priorityColor),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => ref.read(taskListProvider.notifier).deleteTask(task.id),
            child: Icon(
              LucideIcons.trash2,
              size: 14,
              color: widget.isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

