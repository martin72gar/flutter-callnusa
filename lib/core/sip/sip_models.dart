import 'package:meta/meta.dart';

/// SIP registration lifecycle (PRD 6.3).
enum SipRegistrationStatus {
  initial,
  connecting,
  registered,
  refreshing,
  failed,
  unregistered,
}

/// Call lifecycle (PRD 6.4).
enum CallStatus {
  idle,
  incomingRinging,
  outgoingInitiated,
  outgoingRinging,
  connected,
  held,
  ending,
  ended,
  failed,
}

extension CallStatusX on CallStatus {
  bool get isActive => this == CallStatus.connected || this == CallStatus.held;

  bool get isTerminal =>
      this == CallStatus.ended ||
      this == CallStatus.failed ||
      this == CallStatus.idle;

  bool get isRinging =>
      this == CallStatus.incomingRinging || this == CallStatus.outgoingRinging;
}

enum AudioRoute { earpiece, speaker, bluetooth, headset }

/// Why a call ended, derived from the SIP response code by the native layer.
enum CallEndReason { normal, busy, declined, notFound, noAnswer, error }

@immutable
class SipRegistrationEvent {
  const SipRegistrationEvent(
    this.status, {
    this.reason,
    this.isAuthFailure = false,
  });

  final SipRegistrationStatus status;
  final String? reason;

  /// 401/403/407 — credentials were rotated or revoked, so the app must
  /// re-provision rather than keep retrying (PRD 6.3).
  final bool isAuthFailure;

  static SipRegistrationEvent fromNative(Map<dynamic, dynamic> map) {
    final state = map['state'] as String? ?? '';
    return SipRegistrationEvent(
      switch (state) {
        'progress' => SipRegistrationStatus.connecting,
        'ok' => SipRegistrationStatus.registered,
        'refreshing' => SipRegistrationStatus.refreshing,
        'failed' => SipRegistrationStatus.failed,
        'cleared' || 'none' => SipRegistrationStatus.unregistered,
        _ => SipRegistrationStatus.connecting,
      },
      reason: map['reason'] as String?,
      isAuthFailure: map['authFailure'] as bool? ?? false,
    );
  }
}

@immutable
class SipCallEvent {
  const SipCallEvent({
    required this.callId,
    required this.status,
    required this.remoteNumber,
    this.remoteName,
    this.endReason,
    this.isIncoming = false,
  });

  final String callId;
  final CallStatus status;
  final String remoteNumber;
  final String? remoteName;
  final CallEndReason? endReason;
  final bool isIncoming;

  static SipCallEvent fromNative(Map<dynamic, dynamic> map) {
    final state = map['state'] as String? ?? '';
    return SipCallEvent(
      callId: '${map['callId']}',
      status: switch (state) {
        'incoming' => CallStatus.incomingRinging,
        'outgoing_init' => CallStatus.outgoingInitiated,
        'outgoing_ringing' ||
        'outgoing_early_media' => CallStatus.outgoingRinging,
        'connected' || 'stream_running' => CallStatus.connected,
        'paused' || 'paused_by_remote' => CallStatus.held,
        'ending' => CallStatus.ending,
        'ended' || 'released' => CallStatus.ended,
        'error' => CallStatus.failed,
        _ => CallStatus.idle,
      },
      remoteNumber: map['remoteNumber'] as String? ?? '',
      remoteName: map['remoteName'] as String?,
      isIncoming: map['isIncoming'] as bool? ?? false,
      endReason: switch (map['reason'] as String?) {
        'busy' => CallEndReason.busy,
        'declined' => CallEndReason.declined,
        'not_found' => CallEndReason.notFound,
        'no_answer' => CallEndReason.noAnswer,
        'error' => CallEndReason.error,
        'normal' => CallEndReason.normal,
        _ => null,
      },
    );
  }
}

/// Immutable snapshot rendered by the in-call screen (PRD Appendix B).
@immutable
class ActiveCallState {
  const ActiveCallState({
    this.callId,
    this.status = CallStatus.idle,
    this.remoteNumber,
    this.remoteDisplayName,
    this.isMuted = false,
    this.isOnHold = false,
    this.audioRoute = AudioRoute.earpiece,
    this.elapsed = Duration.zero,
    this.isIncoming = false,
    this.endReason,
    this.pendingAction = false,
  });

  final String? callId;
  final CallStatus status;
  final String? remoteNumber;
  final String? remoteDisplayName;
  final bool isMuted;
  final bool isOnHold;
  final AudioRoute audioRoute;
  final Duration elapsed;
  final bool isIncoming;
  final CallEndReason? endReason;

  /// Guards double taps while a start/accept request is in flight (PRD 6.4).
  final bool pendingAction;

  bool get hasCall => callId != null && !status.isTerminal;

  String get displayLabel {
    final name = remoteDisplayName?.trim();
    if (name != null && name.isNotEmpty && name != remoteNumber) return name;
    return remoteNumber ?? '';
  }

  ActiveCallState copyWith({
    String? callId,
    CallStatus? status,
    String? remoteNumber,
    String? remoteDisplayName,
    bool? isMuted,
    bool? isOnHold,
    AudioRoute? audioRoute,
    Duration? elapsed,
    bool? isIncoming,
    CallEndReason? endReason,
    bool? pendingAction,
  }) => ActiveCallState(
    callId: callId ?? this.callId,
    status: status ?? this.status,
    remoteNumber: remoteNumber ?? this.remoteNumber,
    remoteDisplayName: remoteDisplayName ?? this.remoteDisplayName,
    isMuted: isMuted ?? this.isMuted,
    isOnHold: isOnHold ?? this.isOnHold,
    audioRoute: audioRoute ?? this.audioRoute,
    elapsed: elapsed ?? this.elapsed,
    isIncoming: isIncoming ?? this.isIncoming,
    endReason: endReason ?? this.endReason,
    pendingAction: pendingAction ?? this.pendingAction,
  );
}
