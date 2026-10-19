import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../data/repositories/local_focus_guard_repository.dart';
import '../../platform/platform_alert_adapter.dart';
import '../models/focus_guard_models.dart';

class FocusSessionCoordinator {
  final LocalFocusGuardRepository _focusRepo;
  final PlatformAlertAdapter _adapter;

  StreamSubscription? _adapterSubscription;
  Timer? _debounceTimer;
  String? _candidateTarget;
  final ValueNotifier<FocusSession?> currentSessionNotifier = ValueNotifier(null);
  final ValueNotifier<FocusGuardState> currentStateNotifier = ValueNotifier(FocusGuardState.inactive);

  FocusSessionCoordinator(this._focusRepo, this._adapter) {
    _initAdapterListener();
  }

  void _initAdapterListener() {
    _adapterSubscription = _adapter.focusEventStream.listen(
      (data) {
        final kind = data['kind'] as String?;
        final targetApp = data['targetAppId'] as String?;
        if (kind == 'ForegroundTargetChanged' && targetApp != null) {
          handleForegroundChange(targetApp);
        } else if (kind == 'ServiceStateChanged') {
          final state = data['state'] as String?;
          if (state == 'disconnected' || state == 'revoked') {
            handleServiceDegraded(data['error'] as String?);
          }
        }
      },
      onError: (err) {
        handleServiceDegraded(err.toString());
      },
    );
  }

  /// Starts a new Focus Guard session
  Future<FocusSession> startSession({
    required FocusPolicy policy,
    String? taskId,
    int durationMinutes = 25,
    String source = 'manual',
  }) async {
    // End any existing active session first
    final active = await _focusRepo.getActiveSession();
    if (active != null) {
      await endSession(active.id);
    }

    final now = DateTime.now().toUtc();
    final session = FocusSession(
      id: const Uuid().v4(),
      policyId: policy.id,
      taskId: taskId,
      startedAtUtc: now,
      plannedEndUtc: now.add(Duration(minutes: durationMinutes)),
      state: FocusGuardState.monitoring,
      source: source,
    );

    await _focusRepo.createSession(session);
    await _focusRepo.logFocusEvent(FocusEvent(
      id: const Uuid().v4(),
      sessionId: session.id,
      occurredAtUtc: now,
      kind: 'sessionStarted',
      decision: 'monitoring',
    ));

    await _adapter.startFocusMonitoring(
      sessionId: session.id,
      policy: policy,
    );

    currentSessionNotifier.value = session;
    currentStateNotifier.value = FocusGuardState.monitoring;
    return session;
  }

  /// Evaluates incoming foreground app against monitored allowlist, debounce, and cooldown
  Future<void> handleForegroundChange(String targetAppId) async {
    final session = currentSessionNotifier.value;
    if (session == null || !session.state.isActive) return;

    if (session.state == FocusGuardState.paused) {
      await _focusRepo.logFocusEvent(FocusEvent(
        id: const Uuid().v4(),
        sessionId: session.id,
        occurredAtUtc: DateTime.now().toUtc(),
        kind: 'targetDetected',
        targetAppId: targetAppId,
        decision: 'paused',
      ));
      return;
    }

    final policy = await _focusRepo.getPolicy(session.policyId);
    if (policy == null) return;

    // Check if app is in user allowlist of monitored distractions
    final isDistraction = policy.monitoredTargets.any(
      (target) => targetAppId.toLowerCase().contains(target.toLowerCase()),
    );

    if (!isDistraction) {
      // User switched back to safe app / task: cancel debounce
      _debounceTimer?.cancel();
      _candidateTarget = null;
      if (currentStateNotifier.value == FocusGuardState.candidate) {
        currentStateNotifier.value = FocusGuardState.monitoring;
      }
      return;
    }

    // Check active cooldown
    final cooldown = await _focusRepo.getActiveCooldown(session.id, targetAppId);
    if (cooldown != null && !cooldown.isExpired) {
      await _focusRepo.logFocusEvent(FocusEvent(
        id: const Uuid().v4(),
        sessionId: session.id,
        occurredAtUtc: DateTime.now().toUtc(),
        kind: 'targetDetected',
        targetAppId: targetAppId,
        decision: 'suppress_cooldown',
      ));
      return;
    }

    // Target observed: Enter Candidate state and start debounce timer (Section 5.3)
    _candidateTarget = targetAppId;
    currentStateNotifier.value = FocusGuardState.candidate;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(seconds: policy.graceSeconds), () async {
      // Recheck: Ensure candidate target is still active before prompting
      if (_candidateTarget == targetAppId && currentSessionNotifier.value?.state.isActive == true) {
        await _qualifyIntervention(session.id, targetAppId, policy.promptText);
      }
    });
  }

  Future<void> _qualifyIntervention(String sessionId, String targetAppId, String promptText) async {
    currentStateNotifier.value = FocusGuardState.prompting;
    await _focusRepo.logFocusEvent(FocusEvent(
      id: const Uuid().v4(),
      sessionId: sessionId,
      occurredAtUtc: DateTime.now().toUtc(),
      kind: 'promptShown',
      targetAppId: targetAppId,
      decision: 'prompt',
    ));
  }

  /// Escape Action 1: Return to Task (Switches back to FOCUS)
  Future<void> handleReturnToTask(String sessionId) async {
    _debounceTimer?.cancel();
    _candidateTarget = null;
    currentStateNotifier.value = FocusGuardState.monitoring;

    await _focusRepo.logFocusEvent(FocusEvent(
      id: const Uuid().v4(),
      sessionId: sessionId,
      occurredAtUtc: DateTime.now().toUtc(),
      kind: 'promptAction',
      decision: 'returnToTask',
    ));
  }

  /// Escape Action 2: Snooze 5 Min (Adds 5m cooldown for target app)
  Future<void> handleSnooze5m(String sessionId, String? targetAppId) async {
    _debounceTimer?.cancel();
    final until = DateTime.now().toUtc().add(const Duration(minutes: 5));
    if (targetAppId != null) {
      await _focusRepo.setCooldown(FocusCooldown(
        sessionId: sessionId,
        targetAppId: targetAppId,
        untilUtc: until,
        reason: 'User snoozed 5 min',
      ));
    }
    currentStateNotifier.value = FocusGuardState.cooldown;

    await _focusRepo.logFocusEvent(FocusEvent(
      id: const Uuid().v4(),
      sessionId: sessionId,
      occurredAtUtc: DateTime.now().toUtc(),
      kind: 'promptAction',
      targetAppId: targetAppId,
      decision: 'snooze_5m',
    ));

    // Return to monitoring after cooldown timer
    Timer(const Duration(minutes: 5), () {
      if (currentStateNotifier.value == FocusGuardState.cooldown) {
        currentStateNotifier.value = FocusGuardState.monitoring;
      }
    });
  }

  /// Escape Action 3: Pause Session
  Future<void> pauseSession(String sessionId) async {
    _debounceTimer?.cancel();
    await _focusRepo.updateSessionState(sessionId, FocusGuardState.paused);
    currentStateNotifier.value = FocusGuardState.paused;

    await _focusRepo.logFocusEvent(FocusEvent(
      id: const Uuid().v4(),
      sessionId: sessionId,
      occurredAtUtc: DateTime.now().toUtc(),
      kind: 'sessionPaused',
      decision: 'paused',
    ));
  }

  /// Resume Paused Session
  Future<void> resumeSession(String sessionId) async {
    await _focusRepo.updateSessionState(sessionId, FocusGuardState.monitoring);
    currentStateNotifier.value = FocusGuardState.monitoring;

    await _focusRepo.logFocusEvent(FocusEvent(
      id: const Uuid().v4(),
      sessionId: sessionId,
      occurredAtUtc: DateTime.now().toUtc(),
      kind: 'sessionResumed',
      decision: 'resumed',
    ));
  }

  /// Escape Action 4: End Session (Terminal)
  Future<void> endSession(String sessionId) async {
    _debounceTimer?.cancel();
    final now = DateTime.now().toUtc();
    await _focusRepo.updateSessionState(sessionId, FocusGuardState.completed, endedAt: now);
    await _adapter.stopFocusMonitoring(sessionId: sessionId);

    await _focusRepo.logFocusEvent(FocusEvent(
      id: const Uuid().v4(),
      sessionId: sessionId,
      occurredAtUtc: now,
      kind: 'sessionCompleted',
      decision: 'completed',
    ));

    currentSessionNotifier.value = null;
    currentStateNotifier.value = FocusGuardState.completed;
  }

  /// Degraded service state handler
  void handleServiceDegraded(String? reason) {
    _debounceTimer?.cancel();
    currentStateNotifier.value = FocusGuardState.degraded;
    debugPrint('Focus Guard entered Degraded mode: $reason');
  }

  void dispose() {
    _debounceTimer?.cancel();
    _adapterSubscription?.cancel();
  }
}
