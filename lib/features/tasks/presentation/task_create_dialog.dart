import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/minimal_button.dart';
import '../../../data/providers/database_provider.dart';
import '../../../domain/models/critical_alert_models.dart';
import '../../../domain/models/task_item.dart';

class TaskCreateDialog extends ConsumerStatefulWidget {
  final String? initialTitle;

  const TaskCreateDialog({super.key, this.initialTitle});

  @override
  ConsumerState<TaskCreateDialog> createState() => _TaskCreateDialogState();
}

class _TaskCreateDialogState extends ConsumerState<TaskCreateDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  TaskPriority _selectedPriority = TaskPriority.medium;
  DateTime? _selectedDueDate;
  String? _selectedProjectId;

  // Phase 5: Critical Task Alert Engine options
  bool _isCriticalAlert = false;
  DuePolicy _duePolicy = DuePolicy.strict;
  int _leadMinutes = 15;
  QuietHoursPolicy _quietHoursPolicy = QuietHoursPolicy.silent;
  bool _genericLockscreen = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickExactDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDueDate ?? now.add(const Duration(hours: 1))),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDueDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    // If critical alert is toggled, ensure a due date exists
    DateTime? effectiveDueDate = _selectedDueDate;
    if (_isCriticalAlert && effectiveDueDate == null) {
      effectiveDueDate = DateTime.now().add(const Duration(hours: 1));
    }

    await ref.read(taskListProvider.notifier).addTask(
          title: title,
          description: _descController.text.trim(),
          priority: _isCriticalAlert ? TaskPriority.high : _selectedPriority,
          dueAt: effectiveDueDate,
          projectId: _selectedProjectId,
          isCritical: _isCriticalAlert,
          duePolicy: _duePolicy,
          leadMinutes: _leadMinutes,
          quietHoursPolicy: _quietHoursPolicy,
          genericLockscreen: _genericLockscreen,
        );

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.plusCircle, size: 18, color: AppColors.accent),
                      const SizedBox(width: AppTokens.space8),
                      Text(
                        'NEW TASK',
                        style: AppTypography.label(isDark: isDark).copyWith(
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.space20),

              // Title input
              TextField(
                controller: _titleController,
                autofocus: true,
                style: AppTypography.titleMedium(isDark: isDark),
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle: AppTypography.titleMedium(isDark: isDark).copyWith(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: AppTokens.space12),

              // Description input
              TextField(
                controller: _descController,
                maxLines: 2,
                style: AppTypography.body(isDark: isDark),
                decoration: InputDecoration(
                  hintText: 'Add notes or sub-details (optional)',
                  hintStyle: AppTypography.body(isDark: isDark).copyWith(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: AppTokens.space16),

              // Priority Selector
              Text('PRIORITY', style: AppTypography.label(isDark: isDark)),
              const SizedBox(height: AppTokens.space8),
              Row(
                children: TaskPriority.values.map((priority) {
                  final isSelected = _selectedPriority == priority;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppTokens.space8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPriority = priority),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (priority == TaskPriority.high ? AppColors.urgent : (isDark ? AppColors.white : AppColors.textPrimaryLight))
                              : (isDark ? AppColors.darkCardHover : AppColors.lightCardHover),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          priority.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? (priority == TaskPriority.high ? AppColors.white : (isDark ? AppColors.darkBackground : AppColors.white))
                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTokens.space20),

              // Due Date quick toggles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('DUE DATE', style: AppTypography.label(isDark: isDark)),
                  if (_selectedDueDate != null)
                    Text(
                      '${_selectedDueDate!.day}/${_selectedDueDate!.month} ${_selectedDueDate!.hour.toString().padLeft(2, '0')}:${_selectedDueDate!.minute.toString().padLeft(2, '0')}',
                      style: AppTypography.code(isDark: isDark).copyWith(fontSize: 11, color: AppColors.accent),
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.space8),
              Wrap(
                spacing: AppTokens.space8,
                runSpacing: AppTokens.space8,
                children: [
                  _datePill(
                    label: 'Today +1h',
                    isSelected: _selectedDueDate != null && _isSameDay(_selectedDueDate!, DateTime.now()),
                    onTap: () => setState(() => _selectedDueDate = DateTime.now().add(const Duration(hours: 1))),
                    isDark: isDark,
                  ),
                  _datePill(
                    label: 'Tomorrow 9AM',
                    isSelected: _selectedDueDate != null && _isSameDay(_selectedDueDate!, DateTime.now().add(const Duration(days: 1))),
                    onTap: () {
                      final t = DateTime.now().add(const Duration(days: 1));
                      setState(() => _selectedDueDate = DateTime(t.year, t.month, t.day, 9, 0));
                    },
                    isDark: isDark,
                  ),
                  _datePill(
                    label: 'Pick Exact Time',
                    isSelected: false,
                    onTap: _pickExactDateTime,
                    isDark: isDark,
                  ),
                  if (_selectedDueDate != null)
                    _datePill(
                      label: 'Clear',
                      isSelected: false,
                      onTap: () => setState(() => _selectedDueDate = null),
                      isDark: isDark,
                    ),
                ],
              ),
              const SizedBox(height: AppTokens.space20),

              // Phase 5: Critical Alert Profile Expansion Card
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardHover.withValues(alpha: 0.5) : AppColors.lightCardHover.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isCriticalAlert
                        ? AppColors.urgent.withValues(alpha: 0.5)
                        : (isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder),
                    width: _isCriticalAlert ? 1.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.all(AppTokens.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isCriticalAlert ? LucideIcons.bellRing : LucideIcons.bell,
                              size: 16,
                              color: _isCriticalAlert ? AppColors.urgent : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            ),
                            const SizedBox(width: AppTokens.space8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CRITICAL ALERT ENGINE',
                                  style: AppTypography.label(isDark: isDark).copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _isCriticalAlert ? AppColors.urgent : null,
                                  ),
                                ),
                                Text(
                                  'Phase 5: Atomic outbox & escalation ladder',
                                  style: AppTypography.caption(isDark: isDark).copyWith(fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: _isCriticalAlert,
                          activeTrackColor: AppColors.urgent,
                          onChanged: (val) {
                            setState(() {
                              _isCriticalAlert = val;
                              if (val && _selectedDueDate == null) {
                                _selectedDueDate = DateTime.now().add(const Duration(hours: 1));
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    if (_isCriticalAlert) ...[
                      const Divider(height: 16),
                      // Lead Time Selector
                      Text('LEAD TIME BEFORE DUE', style: AppTypography.caption(isDark: isDark).copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [0, 15, 30, 60].map((mins) {
                          final isSel = _leadMinutes == mins;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: GestureDetector(
                              onTap: () => setState(() => _leadMinutes = mins),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSel ? AppColors.urgent : (isDark ? AppColors.darkCard : AppColors.lightCard),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  mins == 0 ? 'Exact' : '${mins}m',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSel ? Colors.white : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      // Due Policy Selector
                      Text('DUE POLICY', style: AppTypography.caption(isDark: isDark).copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _policyChip(
                            label: 'Strict Due',
                            isSelected: _duePolicy == DuePolicy.strict,
                            onTap: () => setState(() => _duePolicy = DuePolicy.strict),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _policyChip(
                            label: 'Grace Window',
                            isSelected: _duePolicy == DuePolicy.gracePeriod,
                            onTap: () => setState(() => _duePolicy = DuePolicy.gracePeriod),
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Quiet Hours Policy
                      Text('QUIET HOURS POLICY', style: AppTypography.caption(isDark: isDark).copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _policyChip(
                            label: 'Silent in Quiet Hours',
                            isSelected: _quietHoursPolicy == QuietHoursPolicy.silent,
                            onTap: () => setState(() => _quietHoursPolicy = QuietHoursPolicy.silent),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _policyChip(
                            label: 'Allow Urgent',
                            isSelected: _quietHoursPolicy == QuietHoursPolicy.allow,
                            onTap: () => setState(() => _quietHoursPolicy = QuietHoursPolicy.allow),
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Privacy & Quiet Hours
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Lock-Screen Privacy', style: AppTypography.bodySmall(isDark: isDark).copyWith(fontWeight: FontWeight.w600)),
                                Text('Hide details on lock screen', style: AppTypography.caption(isDark: isDark).copyWith(fontSize: 10)),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _genericLockscreen,
                            activeTrackColor: AppColors.accent,
                            onChanged: (val) => setState(() => _genericLockscreen = val),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space16),

              // Project Selector
              ref.watch(projectListProvider).when(
                    data: (projects) {
                      if (projects.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PROJECT', style: AppTypography.label(isDark: isDark)),
                          const SizedBox(height: AppTokens.space8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _datePill(
                                  label: 'None',
                                  isSelected: _selectedProjectId == null,
                                  onTap: () => setState(() => _selectedProjectId = null),
                                  isDark: isDark,
                                ),
                                ...projects.map((p) => Padding(
                                      padding: const EdgeInsets.only(left: AppTokens.space8),
                                      child: _datePill(
                                        label: p.name,
                                        isSelected: _selectedProjectId == p.id,
                                        onTap: () => setState(() => _selectedProjectId = p.id),
                                        isDark: isDark,
                                      ),
                                    )),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTokens.space16),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
              const SizedBox(height: AppTokens.space8),

              // Action buttons
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
                    label: _isCriticalAlert ? 'Schedule Critical' : 'Create Task',
                    variant: _isCriticalAlert ? MinimalButtonVariant.primary : MinimalButtonVariant.accent,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _policyChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? AppColors.white : AppColors.textPrimaryLight) : (isDark ? AppColors.darkCard : AppColors.lightCard),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? (isDark ? AppColors.darkBackground : AppColors.white) : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _datePill({
    required String label,
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
}
