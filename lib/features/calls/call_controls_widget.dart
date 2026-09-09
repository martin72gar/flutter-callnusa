import 'package:flutter/material.dart';

import '../../core/sip/sip_models.dart';

/// Round icon button used for every in-call control.
class CallControlButton extends StatelessWidget {
  const CallControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: active ? colors.primary : colors.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(
                icon,
                size: 26,
                color: active ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

/// Accept / decline pair shown while an incoming call is ringing.
class IncomingCallControls extends StatelessWidget {
  const IncomingCallControls({
    super.key,
    required this.onAccept,
    required this.onDecline,
    required this.acceptLabel,
    required this.declineLabel,
    this.busy = false,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String acceptLabel;
  final String declineLabel;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _BigAction(
          color: Colors.red,
          icon: Icons.call_end,
          label: declineLabel,
          onPressed: busy ? null : onDecline,
        ),
        _BigAction(
          color: Colors.green,
          icon: Icons.call,
          label: acceptLabel,
          onPressed: busy ? null : onAccept,
        ),
      ],
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({
    required this.color,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.large(
          heroTag: label,
          backgroundColor: onPressed == null ? Colors.grey : color,
          foregroundColor: Colors.white,
          onPressed: onPressed,
          child: Icon(icon, size: 32),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

/// Mute / hold / speaker row shown once a call is up.
class ActiveCallControls extends StatelessWidget {
  const ActiveCallControls({
    super.key,
    required this.state,
    required this.onToggleMute,
    required this.onToggleHold,
    required this.onToggleSpeaker,
    required this.muteLabel,
    required this.holdLabel,
    required this.speakerLabel,
  });

  final ActiveCallState state;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleHold;
  final VoidCallback onToggleSpeaker;
  final String muteLabel;
  final String holdLabel;
  final String speakerLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = state.status.isActive;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        CallControlButton(
          icon: state.isMuted ? Icons.mic_off : Icons.mic,
          label: muteLabel,
          active: state.isMuted,
          onPressed: enabled ? onToggleMute : null,
        ),
        CallControlButton(
          icon: state.isOnHold ? Icons.play_arrow : Icons.pause,
          label: holdLabel,
          active: state.isOnHold,
          onPressed: enabled ? onToggleHold : null,
        ),
        CallControlButton(
          icon: state.audioRoute == AudioRoute.speaker
              ? Icons.volume_up
              : Icons.hearing,
          label: speakerLabel,
          active: state.audioRoute == AudioRoute.speaker,
          onPressed: enabled ? onToggleSpeaker : null,
        ),
      ],
    );
  }
}
