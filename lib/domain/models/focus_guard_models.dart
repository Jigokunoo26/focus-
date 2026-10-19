import 'package:flutter/foundation.dart';

/// Focus Guard state machine states according to Phase 7 System Design
enum FocusGuardState {
  inactive,
  requestingCapability,
  monitoring,
  candidate,
  prompting,
  cooldown,
  paused,
  degraded,
  completed;

  bool get isActive =>
      this == FocusGuardState.monitoring ||
      this == FocusGuardState.candidate ||
      this == FocusGuardState.prompting ||
      this == FocusGuardState.cooldown ||
      this == FocusGuardState.paused;
}

enum FocusBlockMode {
  reminder,
  overlayPrompt;

  static FocusBlockMode fromString(String val) {
    return FocusBlockMode.values.firstWhere(
      (m) => m.name == val,
      orElse: () => FocusBlockMode.reminder,
    );
  }
}

/// User-owned Focus Policy settings
@immutable
class FocusPolicy {
  final String id;
  final String name;
  final List<String> monitoredTargets; // e.g. ['com.instagram.android', 'com.zhiliaoapp.musically', 'chrome.exe']
  final int graceSeconds; // Debounce before prompting (e.g. 5 seconds)
  final int cooldownSeconds; // Suppression interval after prompt action (e.g. 60 seconds)
  final FocusBlockMode blockMode;
  final String promptText;

  const FocusPolicy({
    required this.id,
    required this.name,
    this.monitoredTargets = const [
      'com.instagram.android',
      'com.zhiliaoapp.musically',
      'com.twitter.android',
      'com.google.android.youtube',
      'com.reddit.frontpage',
      'com.discord',
    ],
    this.graceSeconds = 5,
    this.cooldownSeconds = 60,
    this.blockMode = FocusBlockMode.reminder,
    this.promptText = 'You are distracted. Return to your task.',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'monitored_targets_json': monitoredTargets.join(','),
    'grace_seconds': graceSeconds,
    'cooldown_seconds': cooldownSeconds,
    'block_mode': blockMode.name,
    'prompt_text': promptText,
  };

  factory FocusPolicy.fromMap(Map<String, dynamic> map) {
    final rawTargets = map['monitored_targets_json'] as String? ?? '';
    final targets = rawTargets.isEmpty
        ? <String>[]
        : rawTargets.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return FocusPolicy(
      id: map['id'] as String,
      name: map['name'] as String,
      monitoredTargets: targets.isNotEmpty ? targets : const ['com.instagram.android', 'com.zhiliaoapp.musically'],
      graceSeconds: map['grace_seconds'] as int? ?? 5,
      cooldownSeconds: map['cooldown_seconds'] as int? ?? 60,
      blockMode: FocusBlockMode.fromString(map['block_mode'] as String? ?? 'reminder'),
      promptText: map['prompt_text'] as String? ?? 'You are distracted. Return to your task.',
    );
  }

  FocusPolicy copyWith({
    String? id,
    String? name,
    List<String>? monitoredTargets,
    int? graceSeconds,
    int? cooldownSeconds,
    FocusBlockMode? blockMode,
    String? promptText,
  }) {
    return FocusPolicy(
      id: id ?? this.id,
      name: name ?? this.name,
      monitoredTargets: monitoredTargets ?? this.monitoredTargets,
      graceSeconds: graceSeconds ?? this.graceSeconds,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      blockMode: blockMode ?? this.blockMode,
      promptText: promptText ?? this.promptText,
    );
  }
}

/// One active or completed Focus Guard session
@immutable
class FocusSession {
  final String id;
  final String policyId;
  final String? taskId;
  final DateTime startedAtUtc;
  final DateTime plannedEndUtc;
  final DateTime? endedAtUtc;
  final FocusGuardState state;
  final String source; // 'manual', 'scheduled'

  const FocusSession({
    required this.id,
    required this.policyId,
    this.taskId,
    required this.startedAtUtc,
    required this.plannedEndUtc,
    this.endedAtUtc,
    this.state = FocusGuardState.monitoring,
    this.source = 'manual',
  });

  FocusSession copyWith({
    String? id,
    String? policyId,
    String? taskId,
    DateTime? startedAtUtc,
    DateTime? plannedEndUtc,
    DateTime? endedAtUtc,
    FocusGuardState? state,
    String? source,
  }) {
    return FocusSession(
      id: id ?? this.id,
      policyId: policyId ?? this.policyId,
      taskId: taskId ?? this.taskId,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      plannedEndUtc: plannedEndUtc ?? this.plannedEndUtc,
      endedAtUtc: endedAtUtc ?? this.endedAtUtc,
      state: state ?? this.state,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'policy_id': policyId,
    'task_id': taskId,
    'started_at_utc': startedAtUtc.toUtc().toIso8601String(),
    'planned_end_utc': plannedEndUtc.toUtc().toIso8601String(),
    'ended_at_utc': endedAtUtc?.toUtc().toIso8601String(),
    'state': state.name,
    'source': source,
  };

  factory FocusSession.fromMap(Map<String, dynamic> map) => FocusSession(
    id: map['id'] as String,
    policyId: map['policy_id'] as String,
    taskId: map['task_id'] as String?,
    startedAtUtc: DateTime.parse(map['started_at_utc'] as String),
    plannedEndUtc: DateTime.parse(map['planned_end_utc'] as String),
    endedAtUtc: map['ended_at_utc'] != null
        ? DateTime.parse(map['ended_at_utc'] as String)
        : null,
    state: FocusGuardState.values.firstWhere(
      (s) => s.name == map['state'],
      orElse: () => FocusGuardState.monitoring,
    ),
    source: map['source'] as String? ?? 'manual',
  );
}

/// Redacted and privacy-safe Focus Event
@immutable
class FocusEvent {
  final String id;
  final String sessionId;
  final DateTime occurredAtUtc;
  final String kind; // 'targetDetected', 'promptShown', 'promptAction', 'cooldownStarted', 'sessionPaused', 'sessionResumed'
  final String? targetAppId; // Package name or process name only (no titles or URLs)
  final String decision; // 'prompt', 'suppress_cooldown', 'suppress_grace', 'paused'
  final String? triggerId;

  const FocusEvent({
    required this.id,
    required this.sessionId,
    required this.occurredAtUtc,
    required this.kind,
    this.targetAppId,
    required this.decision,
    this.triggerId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'session_id': sessionId,
    'occurred_at_utc': occurredAtUtc.toUtc().toIso8601String(),
    'kind': kind,
    'target_app_id': targetAppId,
    'decision': decision,
    'trigger_id': triggerId,
  };

  factory FocusEvent.fromMap(Map<String, dynamic> map) => FocusEvent(
    id: map['id'] as String,
    sessionId: map['session_id'] as String,
    occurredAtUtc: DateTime.parse(map['occurred_at_utc'] as String),
    kind: map['kind'] as String,
    targetAppId: map['target_app_id'] as String?,
    decision: map['decision'] as String,
    triggerId: map['trigger_id'] as String?,
  );
}

/// Cooldown tracker preventing repeated prompts on app switch
@immutable
class FocusCooldown {
  final String sessionId;
  final String targetAppId;
  final DateTime untilUtc;
  final String reason;

  const FocusCooldown({
    required this.sessionId,
    required this.targetAppId,
    required this.untilUtc,
    required this.reason,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(untilUtc);

  Map<String, dynamic> toMap() => {
    'session_id': sessionId,
    'target_app_id': targetAppId,
    'until_utc': untilUtc.toUtc().toIso8601String(),
    'reason': reason,
  };

  factory FocusCooldown.fromMap(Map<String, dynamic> map) => FocusCooldown(
    sessionId: map['session_id'] as String,
    targetAppId: map['target_app_id'] as String,
    untilUtc: DateTime.parse(map['until_utc'] as String),
    reason: map['reason'] as String,
  );
}

/// Live adapter health tracking
@immutable
class AdapterHealth {
  final String platform;
  final String serviceState; // 'ready', 'disconnected', 'permissionRevoked', 'unsupported'
  final DateTime? lastHeartbeat;
  final String? lastErrorCode;

  const AdapterHealth({
    required this.platform,
    required this.serviceState,
    this.lastHeartbeat,
    this.lastErrorCode,
  });

  Map<String, dynamic> toMap() => {
    'platform': platform,
    'service_state': serviceState,
    'last_heartbeat_utc': lastHeartbeat?.toUtc().toIso8601String(),
    'last_error_code': lastErrorCode,
  };
}
