import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/sip/sip_models.dart';
import '../../shared/utils/error_messages.dart';
import '../../shared/utils/extensions.dart';
import '../../shared/utils/formatters.dart';
import 'call_controls_widget.dart';

/// Full-screen call UI, used for both directions.
///
/// It is purely a view over [activeCallProvider]: every action goes through the
/// controller, so a hangup from the native call UI unwinds this screen exactly
/// the same way as tapping End here.
class ActiveCallScreen extends ConsumerWidget {
  const ActiveCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final call = ref.watch(activeCallProvider);
    final controller = ref.read(activeCallProvider.notifier);
    final showRecordingNotice = ref
        .watch(provisioningStateProvider)
        .showsRecordingNotice;

    final statusText = switch (call.status) {
      CallStatus.incomingRinging => l10n.incomingCall,
      CallStatus.outgoingInitiated => l10n.outgoingCall,
      CallStatus.outgoingRinging => l10n.callRinging,
      CallStatus.connected => Formatters.duration(call.elapsed),
      CallStatus.held => l10n.callOnHold,
      CallStatus.ending => l10n.callEnding,
      CallStatus.failed => l10n.callFailed,
      CallStatus.ended => callEndMessage(l10n, call.endReason),
      CallStatus.idle => '',
    };

    return PopScope(
      // The call screen is not dismissible by back: ending a call must be an
      // explicit action so a stray gesture cannot leave a call running unseen.
      canPop: call.status.isTerminal,
      child: Scaffold(
        backgroundColor: context.colors.surfaceContainerLowest,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const Spacer(),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: context.colors.primaryContainer,
                  child: Icon(
                    call.isIncoming ? Icons.call_received : Icons.call_made,
                    size: 40,
                    color: context.colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  call.displayLabel.isEmpty
                      ? l10n.unknownCaller
                      : call.displayLabel,
                  textAlign: TextAlign.center,
                  style: context.texts.headlineSmall,
                ),
                if (call.remoteDisplayName != null &&
                    call.remoteNumber != null &&
                    call.remoteDisplayName != call.remoteNumber)
                  Text(call.remoteNumber!, style: context.texts.bodyMedium),
                const SizedBox(height: 8),
                Text(statusText, style: context.texts.titleMedium),
                if (showRecordingNotice && call.status.isActive) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        size: 12,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.recordingNotice,
                        style: context.texts.labelMedium,
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                if (call.status.isActive || call.status == CallStatus.ending)
                  ActiveCallControls(
                    state: call,
                    onToggleMute: controller.toggleMute,
                    onToggleHold: controller.toggleHold,
                    onToggleSpeaker: controller.toggleSpeaker,
                    muteLabel: call.isMuted ? l10n.unmute : l10n.mute,
                    holdLabel: call.isOnHold ? l10n.resume : l10n.hold,
                    speakerLabel: l10n.speaker,
                  ),
                const SizedBox(height: 32),
                if (call.status == CallStatus.incomingRinging)
                  IncomingCallControls(
                    busy: call.pendingAction,
                    acceptLabel: l10n.accept,
                    declineLabel: l10n.decline,
                    onAccept: controller.accept,
                    onDecline: controller.decline,
                  )
                else if (!call.status.isTerminal)
                  Center(
                    child: FloatingActionButton.large(
                      heroTag: 'hangup',
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      onPressed: controller.hangUp,
                      child: const Icon(Icons.call_end, size: 32),
                    ),
                  )
                else
                  Center(
                    child: TextButton(
                      onPressed: controller.dismiss,
                      child: Text(l10n.ok),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
