import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../shared/models/app_exception.dart';
import '../../shared/models/call_history_entry.dart';
import '../diagnostics/logger.dart';
import '../notification/callkit_service.dart';
import 'sip_models.dart';

/// Single source of truth for the call currently on screen.
///
/// Two inputs drive it — Liblinphone call events and the native call UI
/// (CallKit / Telecom) — and they must stay consistent: an action from either
/// side is applied to the other exactly once, and a terminal state always ends
/// the OS call and writes exactly one history entry.
///
/// MVP scope: one call at a time. A second incoming INVITE while a call is
/// active is declined by the SIP stack.
class CallController extends Notifier<ActiveCallState> {
  StreamSubscription<SipCallEvent>? _callSub;
  StreamSubscription<NativeCallCommand>? _nativeSub;
  Timer? _tick;

  DateTime? _startedAt;
  DateTime? _answeredAt;
  bool _historyWritten = false;

  @override
  ActiveCallState build() {
    _callSub = ref.read(sipServiceProvider).callEvents.listen(_onSipEvent);
    _nativeSub = ref
        .read(callKitServiceProvider)
        .commands
        .listen(_onNativeCommand);

    ref.onDispose(() {
      _callSub?.cancel();
      _nativeSub?.cancel();
      _tick?.cancel();
    });

    return const ActiveCallState();
  }

  // ---- Outgoing ----------------------------------------------------------

  /// Places a call. Returns `false` when it could not be started, in which case
  /// [state.endReason] and the thrown-free error are surfaced by the UI.
  Future<bool> startCall(String destination, {String? displayName}) async {
    if (state.pendingAction || state.hasCall) return false;
    if (destination.trim().isEmpty) return false;

    if (!await _ensureMicrophonePermission()) {
      throw const AppException(
        AppErrorKind.platform,
        code: 'MIC_PERMISSION_DENIED',
      );
    }

    state = ActiveCallState(
      status: CallStatus.outgoingInitiated,
      remoteNumber: destination,
      remoteDisplayName: displayName,
      pendingAction: true,
    );

    try {
      final callId = await ref.read(sipServiceProvider).startCall(destination);
      _beginCall(
        callId: callId,
        number: destination,
        name: displayName,
        incoming: false,
      );
      await ref
          .read(callKitServiceProvider)
          .reportOutgoing(
            sipCallId: callId,
            number: destination,
            displayName: displayName,
          );
      return true;
    } on AppException catch (e) {
      log.error('call', 'could not start call: $e');
      state = state.copyWith(
        status: CallStatus.failed,
        endReason: CallEndReason.error,
        pendingAction: false,
      );
      return false;
    }
  }

  // ---- User actions ------------------------------------------------------

  Future<void> accept() async {
    final id = state.callId;
    if (id == null || state.pendingAction) return;
    state = state.copyWith(pendingAction: true);
    await ref.read(sipServiceProvider).acceptCall(id);
  }

  Future<void> decline() async {
    final id = state.callId;
    if (id == null) return;
    await ref.read(sipServiceProvider).declineCall(id);
  }

  Future<void> hangUp() async {
    final id = state.callId;
    if (id == null) return;
    state = state.copyWith(status: CallStatus.ending);
    await ref.read(sipServiceProvider).endCall(id);
  }

  Future<void> toggleMute() async {
    final id = state.callId;
    if (id == null) return;
    final muted = !state.isMuted;
    await ref.read(sipServiceProvider).setMuted(id, muted);
    state = state.copyWith(isMuted: muted);
  }

  Future<void> toggleHold() async {
    final id = state.callId;
    if (id == null) return;
    final held = !state.isOnHold;
    await ref.read(sipServiceProvider).setHeld(id, held);
    state = state.copyWith(
      isOnHold: held,
      status: held ? CallStatus.held : CallStatus.connected,
    );
  }

  Future<void> toggleSpeaker() async {
    final route = state.audioRoute == AudioRoute.speaker
        ? AudioRoute.earpiece
        : AudioRoute.speaker;
    await setAudioRoute(route);
  }

  Future<void> setAudioRoute(AudioRoute route) async {
    await ref.read(sipServiceProvider).setAudioRoute(route);
    state = state.copyWith(audioRoute: route);
  }

  Future<void> sendDtmf(String digit) async {
    final id = state.callId;
    if (id == null) return;
    await ref.read(sipServiceProvider).sendDtmf(id, digit);
  }

  /// Clears a terminal call so the UI can leave the call screen.
  void dismiss() {
    if (!state.status.isTerminal) return;
    state = const ActiveCallState();
  }

  // ---- Event handling ----------------------------------------------------

  void _onSipEvent(SipCallEvent event) {
    // Ignore events for a call we are not tracking (e.g. a second INVITE that
    // the stack already rejected).
    if (state.callId != null && event.callId != state.callId) {
      log.debug('call', 'ignoring event for untracked call ${event.callId}');
      return;
    }

    switch (event.status) {
      case CallStatus.incomingRinging:
        _onIncoming(event);
      case CallStatus.connected:
        _onConnected();
      case CallStatus.held:
        state = state.copyWith(status: CallStatus.held, isOnHold: true);
      case CallStatus.ended || CallStatus.failed:
        _onTerminated(event);
      case _:
        state = state.copyWith(status: event.status, pendingAction: false);
    }
  }

  void _onIncoming(SipCallEvent event) {
    _beginCall(
      callId: event.callId,
      number: event.remoteNumber,
      name: event.remoteName,
      incoming: true,
    );

    final settings = ref.read(settingsProvider);
    unawaited(
      ref
          .read(callKitServiceProvider)
          .reportIncoming(
            sipCallId: event.callId,
            number: event.remoteNumber,
            displayName: event.remoteName,
            vibrate: settings.vibrate,
            ringtone: settings.ringtone == 'default' ? null : settings.ringtone,
          ),
    );

    if (settings.autoAnswer) unawaited(accept());
  }

  void _onConnected() {
    _answeredAt ??= DateTime.now();
    state = state.copyWith(
      status: CallStatus.connected,
      isOnHold: false,
      pendingAction: false,
    );
    _startTimer();

    final callId = state.callId;
    if (callId != null) {
      unawaited(ref.read(callKitServiceProvider).reportConnected(callId));
    }

    // Speakerphone preference: user setting first, backend policy as fallback.
    final preferSpeaker =
        ref.read(settingsProvider).defaultSpeaker ||
        (ref.read(provisioningStateProvider).config?.policy.defaultSpeaker ??
            false);
    if (preferSpeaker && state.audioRoute != AudioRoute.speaker) {
      unawaited(setAudioRoute(AudioRoute.speaker));
    }
  }

  void _onTerminated(SipCallEvent event) {
    _tick?.cancel();
    final callId = state.callId ?? event.callId;
    unawaited(ref.read(callKitServiceProvider).reportEnded(callId));
    _writeHistory(event);

    state = state.copyWith(
      status: event.status,
      endReason: event.endReason ?? CallEndReason.normal,
      pendingAction: false,
    );
  }

  void _onNativeCommand(NativeCallCommand command) {
    if (state.callId != null && command.sipCallId != state.callId) return;
    switch (command.action) {
      case NativeCallAction.accept:
        unawaited(accept());
      case NativeCallAction.decline:
        unawaited(decline());
      case NativeCallAction.end:
        unawaited(hangUp());
      case NativeCallAction.timeout:
        unawaited(decline());
      case NativeCallAction.toggleHold:
        if (command.value != state.isOnHold) unawaited(toggleHold());
      case NativeCallAction.toggleMute:
        if (command.value != state.isMuted) unawaited(toggleMute());
    }
  }

  // ---- Helpers -----------------------------------------------------------

  void _beginCall({
    required String callId,
    required String number,
    required String? name,
    required bool incoming,
  }) {
    _startedAt = DateTime.now();
    _answeredAt = null;
    _historyWritten = false;
    state = ActiveCallState(
      callId: callId,
      status: incoming
          ? CallStatus.incomingRinging
          : CallStatus.outgoingInitiated,
      remoteNumber: number,
      remoteDisplayName: name,
      isIncoming: incoming,
    );
  }

  void _startTimer() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final answeredAt = _answeredAt;
      if (answeredAt == null) return;
      state = state.copyWith(elapsed: DateTime.now().difference(answeredAt));
    });
  }

  /// Writes exactly one history row per call. Guarded because Liblinphone
  /// reports both `End` and `Released` for the same call.
  void _writeHistory(SipCallEvent event) {
    if (_historyWritten) return;
    _historyWritten = true;

    final startedAt = _startedAt ?? DateTime.now();
    final answeredAt = _answeredAt;
    final result = switch ((answeredAt, state.isIncoming, event.endReason)) {
      (final DateTime _, _, _) => CallResult.answered,
      (null, true, CallEndReason.declined) => CallResult.rejected,
      (null, true, _) => CallResult.missed,
      (null, false, CallEndReason.busy) => CallResult.failed,
      (null, false, CallEndReason.normal) => CallResult.missed,
      (null, false, _) => CallResult.failed,
    };

    final entry = CallHistoryEntry(
      id: const Uuid().v4(),
      direction: state.isIncoming
          ? CallDirection.inbound
          : CallDirection.outbound,
      counterpartyNumber: state.remoteNumber ?? event.remoteNumber,
      counterpartyName: state.remoteDisplayName,
      result: result,
      startedAt: startedAt,
      answeredAt: answeredAt,
      endedAt: DateTime.now(),
      durationSeconds: answeredAt == null
          ? 0
          : DateTime.now().difference(answeredAt).inSeconds,
    );
    unawaited(ref.read(callHistoryDaoProvider).upsert(entry));
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) log.warn('call', 'microphone permission denied');
    return status.isGranted;
  }
}
