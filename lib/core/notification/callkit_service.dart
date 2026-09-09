import 'dart:async';

import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

import '../../config/constants.dart';
import '../diagnostics/logger.dart';

/// Actions the user performed in the *native* call UI (CallKit on iOS,
/// the Telecom/full-screen incoming UI on Android).
enum NativeCallAction { accept, decline, end, timeout, toggleHold, toggleMute }

class NativeCallCommand {
  const NativeCallCommand(this.action, this.sipCallId, {this.value = false});

  final NativeCallAction action;
  final String sipCallId;

  /// Payload for the toggle actions (`isOnHold` / `isMuted`).
  final bool value;
}

/// Bridges Liblinphone calls to the OS call UI.
///
/// iOS requires a CallKit UUID; the SIP call id from Liblinphone is not one, so
/// this service keeps the mapping in both directions. Every call reported to the
/// OS must also be *ended* there exactly once, otherwise iOS kills the app for
/// leaking a CXProvider call (PRD 6.4).
class CallKitService {
  CallKitService();

  final _uuid = const Uuid();
  final _commands = StreamController<NativeCallCommand>.broadcast();
  final Map<String, String> _sipToNative = {};
  final Map<String, String> _nativeToSip = {};
  StreamSubscription<CallEvent?>? _subscription;

  Stream<NativeCallCommand> get commands => _commands.stream;

  void start() {
    _subscription ??= FlutterCallkitIncoming.onEvent.listen(_onEvent);
  }

  String _nativeIdFor(String sipCallId) =>
      _sipToNative.putIfAbsent(sipCallId, () {
        final id = _uuid.v4();
        _nativeToSip[id] = sipCallId;
        return id;
      });

  /// Shows the system incoming-call UI. Safe to call from a background isolate
  /// handling a VoIP push before the SIP stack has finished waking up.
  Future<void> reportIncoming({
    required String sipCallId,
    required String number,
    String? displayName,
    bool vibrate = true,
    String? ringtone,
  }) async {
    final id = _nativeIdFor(sipCallId);
    await FlutterCallkitIncoming.showCallkitIncoming(
      CallKitParams(
        id: id,
        nameCaller: displayName?.isNotEmpty == true ? displayName : number,
        appName: AppConstants.appName,
        handle: number,
        type: 0, // audio
        extra: {'sip_call_id': sipCallId},
        android: AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          isShowCallID: true,
          isShowFullLockedScreen: true,
          ringtonePath: ringtone ?? 'ringtone_default',
          backgroundColor: '#0B3D91',
          actionColor: '#4CAF50',
        ),
        ios: IOSParams(
          handleType: 'number',
          supportsHolding: true,
          supportsDTMF: true,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: ringtone ?? 'system_ringtone_default',
        ),
      ),
    );
    log.info('callkit', 'reported incoming call $sipCallId');
  }

  /// Registers an outgoing call with the OS so it appears in the system UI and
  /// in call recents.
  Future<void> reportOutgoing({
    required String sipCallId,
    required String number,
    String? displayName,
  }) async {
    await FlutterCallkitIncoming.startCall(
      CallKitParams(
        id: _nativeIdFor(sipCallId),
        nameCaller: displayName ?? number,
        appName: AppConstants.appName,
        handle: number,
        type: 0,
        extra: {'sip_call_id': sipCallId},
        ios: const IOSParams(handleType: 'number', supportsHolding: true),
      ),
    );
  }

  Future<void> reportConnected(String sipCallId) async {
    final id = _sipToNative[sipCallId];
    if (id != null) await FlutterCallkitIncoming.setCallConnected(id);
  }

  /// Ends the OS-side call. Idempotent: the mapping is removed first so a
  /// hangup arriving from both SIP and CallKit only ends the call once.
  Future<void> reportEnded(String sipCallId) async {
    final id = _sipToNative.remove(sipCallId);
    if (id == null) return;
    _nativeToSip.remove(id);
    await FlutterCallkitIncoming.endCall(id);
  }

  Future<void> endAll() async {
    _sipToNative.clear();
    _nativeToSip.clear();
    await FlutterCallkitIncoming.endAllCalls();
  }

  void _onEvent(CallEvent? event) {
    if (event == null) return;

    String? sipId(CallKitParams params) =>
        params.extra?['sip_call_id'] as String? ?? _nativeToSip[params.id];

    switch (event) {
      case CallEventActionCallAccept(:final callKitParams):
        _emit(NativeCallAction.accept, sipId(callKitParams));
      case CallEventActionCallDecline(:final callKitParams):
        _emit(NativeCallAction.decline, sipId(callKitParams));
      case CallEventActionCallEnded(:final callKitParams):
        _emit(NativeCallAction.end, sipId(callKitParams));
      case CallEventActionCallTimeout(:final id):
        _emit(NativeCallAction.timeout, _nativeToSip[id]);
      case CallEventActionCallToggleHold(:final id, :final isOnHold):
        _emit(NativeCallAction.toggleHold, _nativeToSip[id], value: isOnHold);
      case CallEventActionCallToggleMute(:final id, :final isMuted):
        _emit(NativeCallAction.toggleMute, _nativeToSip[id], value: isMuted);
      case _:
        break;
    }
  }

  void _emit(NativeCallAction action, String? sipCallId, {bool value = false}) {
    if (sipCallId == null) {
      log.warn('callkit', 'native ${action.name} for an unknown call, ignored');
      return;
    }
    log.info('callkit', 'native ${action.name} for $sipCallId');
    _commands.add(NativeCallCommand(action, sipCallId, value: value));
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _commands.close();
  }
}
