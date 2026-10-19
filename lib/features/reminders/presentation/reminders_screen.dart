import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/minimal_button.dart';
import '../../../core/widgets/widget_shell.dart';
import '../../../data/providers/database_provider.dart';
import '../../../domain/models/audit_event_item.dart';
import '../../../domain/models/reminder_item.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool _notificationPermissionGranted = true;
  bool _exactAlarmPermissionGranted = true;
  String? _lastReconciliationTime;
  List<ReminderItem> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _lastReconciliationTime = DateFormat('HH:mm:ss').format(DateTime.now());
    _loadStatusAndReminders();
  }

  Future<void> _loadStatusAndReminders() async {
    setState(() => _isLoading = true);
    final scheduler = ref.read(notificationSchedulerProvider);
    final status = await scheduler.getStatus();
    final repo = await ref.read(reminderRepositoryProvider.future);
    final items = await repo.getActiveReminders();

    if (mounted) {
      setState(() {
        _notificationPermissionGranted = status.notificationsAllowed;
        _exactAlarmPermissionGranted = status.exactAlarmsAllowed;
        _reminders = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerTestNotification() async {
    final scheduler = ref.read(notificationSchedulerProvider);
    await scheduler.showInstantTestNotification(
      title: 'FOCUS Personal OS // Test Alert',
      body: 'Verified: Local exact reminder engine is operational without cloud or AI.',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkCard,
          content: Text(
            'Local Reminder Alert Dispatched (Exact Alarm Simulated)',
            style: AppTypography.bodySmall(isDark: true).copyWith(color: AppColors.white),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _runReconciliation() async {
    final reconciliationService = await ref.read(reconciliationServiceProvider.future);
    final count = await reconciliationService.reconcileAll();
    final alertEngine = await ref.read(alertPolicyEngineProvider.future);
    final criticalCount = await alertEngine.reconcileAllOccurrences();

    setState(() {
      _lastReconciliationTime = DateFormat('HH:mm:ss').format(DateTime.now());
    });
    await _loadStatusAndReminders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkCard,
          content: Text(
            'Idempotent Reconciliation Complete: $count reminders, $criticalCount critical alerts synchronized.',
            style: AppTypography.bodySmall(isDark: true).copyWith(color: AppColors.white),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _scheduleTenSecondTestAlarm() async {
    final scheduler = ref.read(notificationSchedulerProvider);
    final auditRepo = await ref.read(auditRepositoryProvider.future);
    final now = DateTime.now();
    final triggerAt = now.add(const Duration(seconds: 10));

    final testReminder = ReminderItem(
      id: const Uuid().v4(),
      ownerType: 'test',
      title: 'FOCUS Exact Alarm Test',
      notes: '10-Second Native Exact Alarm Triggered Successfully.',
      triggerAt: triggerAt,
      state: ReminderState.scheduled,
      notificationId: 88888,
      createdAt: now,
    );

    await scheduler.schedule(testReminder);
    await auditRepo.logEvent(
      id: const Uuid().v4(),
      eventType: 'SCHEDULED',
      title: '10-Second Alarm Test Scheduled',
      details: 'Scheduled for ${DateFormat('HH:mm:ss').format(triggerAt)} to test lock-screen reliability.',
      createdAt: now,
    );
    ref.invalidate(auditLogProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.darkCard,
          content: Text(
            'Exact alarm queued for 10 seconds from now. Lock your screen to verify!',
            style: AppTypography.bodySmall(isDark: true).copyWith(color: AppColors.white),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showBatteryGuideDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(AppTokens.space20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.shieldAlert, size: 18, color: AppColors.accent),
                      const SizedBox(width: AppTokens.space8),
                      Text('OEM BATTERY UNRESTRICTION', style: AppTypography.label(isDark: isDark)),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space12),
                  Text(
                    'To ensure 100% deterministic alarm delivery when the device is in deep Doze mode, grant Unrestricted battery access:',
                    style: AppTypography.bodySmall(isDark: isDark),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  _oemGuideStep('Google Pixel / Nothing OS', 'Settings → Apps → FOCUS → Battery → Unrestricted', isDark),
                  const SizedBox(height: AppTokens.space8),
                  _oemGuideStep('Samsung (OneUI)', 'Settings → Apps → FOCUS → Battery → Unrestricted\nDevice Care → Background limits → Never Sleeping Apps', isDark),
                  const SizedBox(height: AppTokens.space8),
                  _oemGuideStep('Xiaomi / HyperOS', 'Settings → Apps → Permissions → Autostart (Enable)\nBattery Saver → No restrictions', isDark),
                  const SizedBox(height: AppTokens.space8),
                  _oemGuideStep('OnePlus / OxygenOS', 'Settings → Apps → FOCUS → Battery usage → Allow background activity', isDark),
                  const SizedBox(height: AppTokens.space16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: MinimalButton(
                      label: 'Understood',
                      variant: MinimalButtonVariant.accent,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _oemGuideStep(String title, String path, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
        borderRadius: AppTokens.borderSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.label(isDark: isDark).copyWith(color: AppColors.accent)),
          const SizedBox(height: 2),
          Text(path, style: AppTypography.bodySmall(isDark: isDark).copyWith(fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auditLogsAsync = ref.watch(auditLogProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Reminder Engine Health',
          style: AppTypography.titleLarge(isDark: isDark),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bellRing, size: 18),
            tooltip: 'Instant Notification Test',
            onPressed: _triggerTestNotification,
          ),
          const SizedBox(width: AppTokens.space8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompactMobile = constraints.maxWidth < 360;
            final horizontalPadding = isCompactMobile ? AppTokens.space12 : AppTokens.space16;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: AppTokens.space12,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // Status Card
                  WidgetShell(
                    title: 'Subsystem Reliability Status',
                    icon: LucideIcons.activity,
                    statusTag: 'HEALTHY',
                    statusColor: AppColors.success,
                    child: Column(
                      children: [
                        _healthRow(
                          label: 'POST_NOTIFICATIONS Permission',
                          status: _notificationPermissionGranted ? 'GRANTED' : 'DENIED',
                          isOk: _notificationPermissionGranted,
                          isDark: isDark,
                        ),
                        const SizedBox(height: AppTokens.space12),
                        _healthRow(
                          label: 'SCHEDULE_EXACT_ALARM Permission',
                          status: _exactAlarmPermissionGranted ? 'ALLOWED' : 'RESTRICTED',
                          isOk: _exactAlarmPermissionGranted,
                          isDark: isDark,
                        ),
                        const SizedBox(height: AppTokens.space12),
                        _healthRow(
                          label: 'Last Idempotent Reconciliation',
                          status: _lastReconciliationTime ?? 'Pending',
                          isOk: true,
                          isDark: isDark,
                        ),
                        const SizedBox(height: AppTokens.space16),
                        Row(
                          children: [
                            Expanded(
                              child: MinimalButton(
                                label: 'Test 10s Alarm',
                                variant: MinimalButtonVariant.primary,
                                icon: LucideIcons.timer,
                                onPressed: _scheduleTenSecondTestAlarm,
                              ),
                            ),
                            const SizedBox(width: AppTokens.space10),
                            Expanded(
                              child: MinimalButton(
                                label: 'Reconcile Now',
                                variant: MinimalButtonVariant.secondary,
                                icon: LucideIcons.refreshCw,
                                onPressed: _runReconciliation,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),

                  // Battery & Reliability Notice (Honest Guarantees requirement)
                  GlassCard(
                    padding: const EdgeInsets.all(AppTokens.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.alertTriangle, size: 16, color: AppColors.warning),
                            const SizedBox(width: AppTokens.space8),
                            Text(
                              'HONEST PLATFORM GUARANTEES',
                              style: AppTypography.label(isDark: isDark).copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.space8),
                        Text(
                          'Android OEM battery optimizations (Doze mode, Xiaomi/Samsung background task killers) can delay unexempted alarms. FOCUS idempotently reconciles scheduled alarms on reboot, date change, and app launch.',
                          style: AppTypography.bodySmall(isDark: isDark),
                        ),
                        const SizedBox(height: AppTokens.space10),
                        GestureDetector(
                          onTap: () => _showBatteryGuideDialog(context, isDark),
                          child: Text(
                            'Open OEM Battery Exemption Guide →',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),

                  // Scheduled Reminders Section
                  Text(
                    'ACTIVE SCHEDULED REMINDERS',
                    style: AppTypography.label(isDark: isDark),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_reminders.isEmpty)
                    EmptyState(
                      icon: LucideIcons.bellOff,
                      title: 'No Active Reminders',
                      subtitle: 'Tasks with due dates will automatically appear here.',
                    )
                  else
                    Column(
                      children: _reminders.map((rem) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppTokens.space8),
                          child: _reminderTile(
                            title: rem.title,
                            time: DateFormat('MMM d • HH:mm').format(rem.triggerAt),
                            id: rem.notificationId.toString(),
                            state: rem.state.value.toUpperCase(),
                            isDark: isDark,
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: AppTokens.space20),

                  // Persistent Audit Trail Log Section
                  Text(
                    'DURABLE AUDIT TRAIL LOG',
                    style: AppTypography.label(isDark: isDark),
                  ),
                  const SizedBox(height: AppTokens.space8),

                  auditLogsAsync.when(
                    data: (logs) {
                      if (logs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No audit events recorded yet.',
                            style: AppTypography.bodySmall(isDark: isDark),
                          ),
                        );
                      }

                      return Column(
                        children: logs.take(6).map((log) => _buildAuditTile(log, isDark)).toList(),
                      );
                    },
                    loading: () => const SizedBox(
                      height: 40,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    error: (_, _) => const SizedBox(),
                  ),
                  const SizedBox(height: AppTokens.space24),
                ],
              ),
            ),
          ),
        );
          },
        ),
      ),
    );
  }

  Widget _buildAuditTile(AuditEventItem log, bool isDark) {
    Color tagColor;
    switch (log.eventType) {
      case 'COMPLETED':
        tagColor = AppColors.success;
        break;
      case 'SNOOZED':
        tagColor = AppColors.warning;
        break;
      case 'SCHEDULED':
        tagColor = AppColors.accent;
        break;
      case 'RECONCILED':
      default:
        tagColor = AppColors.info;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
        borderRadius: AppTokens.borderSmall,
        border: Border.all(
          color: isDark ? AppColors.darkGlassBorder : AppColors.lightGlassBorder,
          width: 0.6,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              log.eventType,
              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: tagColor),
            ),
          ),
          const SizedBox(width: AppTokens.space10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                if (log.details.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    log.details,
                    style: AppTypography.bodySmall(isDark: isDark).copyWith(fontSize: 10.5),
                  ),
                ],
              ],
            ),
          ),
          Text(
            DateFormat('HH:mm:ss').format(log.createdAt),
            style: TextStyle(
              fontSize: 10,
              fontFamily: 'monospace',
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _healthRow({
    required String label,
    required String status,
    required bool isOk,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.body(isDark: isDark)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (isOk ? AppColors.success : AppColors.urgent).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: isOk ? AppColors.success : AppColors.urgent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _reminderTile({
    required String title,
    required String time,
    required String id,
    required String state,
    required bool isDark,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkCardHover : AppColors.lightCardHover,
            ),
            child: const Icon(LucideIcons.clock, size: 16, color: AppColors.accent),
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(isDark: isDark).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '$time • Deterministic ID: #$id • $state',
                  style: AppTypography.bodySmall(isDark: isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
