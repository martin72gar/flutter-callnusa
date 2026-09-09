import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/sip/sip_models.dart';
import '../utils/extensions.dart';

/// Always-visible SIP registration indicator. Tapping a failed state retries
/// immediately instead of waiting out the backoff.
class RegistrationBadge extends ConsumerWidget {
  const RegistrationBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(sipStatusProvider).value ?? SipRegistrationStatus.initial;
    final l10n = context.l10n;

    final (color, label) = switch (status) {
      SipRegistrationStatus.registered => (
        Colors.green,
        l10n.registrationRegistered,
      ),
      SipRegistrationStatus.connecting || SipRegistrationStatus.initial => (
        Colors.orange,
        l10n.registrationConnecting,
      ),
      SipRegistrationStatus.refreshing => (
        Colors.orange,
        l10n.registrationRefreshing,
      ),
      SipRegistrationStatus.failed => (Colors.red, l10n.registrationFailed),
      SipRegistrationStatus.unregistered => (
        Colors.grey,
        l10n.registrationUnregistered,
      ),
    };

    final canRetry =
        status == SipRegistrationStatus.failed ||
        status == SipRegistrationStatus.unregistered;

    return InkWell(
      onTap: canRetry ? () => ref.read(sipServiceProvider).retryNow() : null,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(label, style: context.texts.labelMedium),
            if (canRetry) ...[
              const SizedBox(width: 4),
              const Icon(Icons.refresh, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}
