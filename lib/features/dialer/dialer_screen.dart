import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../shared/models/app_exception.dart';
import '../../shared/utils/error_messages.dart';
import '../../shared/utils/extensions.dart';
import 'dial_pad_widget.dart';
import 'dialer_view_model.dart';

class DialerScreen extends ConsumerWidget {
  const DialerScreen({super.key});

  Future<void> _call(BuildContext context, WidgetRef ref) async {
    final number = ref.read(dialerProvider);
    if (number.isEmpty) return;
    try {
      final started = await ref
          .read(activeCallProvider.notifier)
          .startCall(number);
      if (started) ref.read(dialerProvider.notifier).clear();
    } on AppException catch (e) {
      if (context.mounted) context.showSnack(messageFor(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final number = ref.watch(dialerProvider);
    final provisioning = ref.watch(provisioningStateProvider);
    final call = ref.watch(activeCallProvider);

    final canCall =
        number.isNotEmpty &&
        provisioning.canDialOut &&
        !call.hasCall &&
        !call.pendingAction;

    return Column(
      children: [
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            number.isEmpty ? l10n.dialerHint : number,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: number.isEmpty
                ? context.texts.titleMedium?.copyWith(
                    color: context.colors.outline,
                  )
                : context.texts.displaySmall,
          ),
        ),
        if (!provisioning.canDialOut && provisioning.isReady)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.outboundCallingDisabled,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.error,
              ),
            ),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: DialPadWidget(
            onKey: (key) => ref.read(dialerProvider.notifier).press(key),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72),
            FloatingActionButton.large(
              heroTag: 'call',
              backgroundColor: canCall
                  ? Colors.green
                  : context.colors.surfaceContainerHighest,
              foregroundColor: canCall ? Colors.white : context.colors.outline,
              onPressed: canCall ? () => _call(context, ref) : null,
              child: const Icon(Icons.call),
            ),
            SizedBox(
              width: 72,
              child: number.isEmpty
                  ? null
                  // Long press clears the whole number, as native dialers do.
                  : GestureDetector(
                      onLongPress: () =>
                          ref.read(dialerProvider.notifier).clear(),
                      child: IconButton(
                        iconSize: 28,
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).deleteButtonTooltip,
                        onPressed: () =>
                            ref.read(dialerProvider.notifier).backspace(),
                        icon: const Icon(Icons.backspace_outlined),
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
