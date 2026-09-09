import 'package:flutter/material.dart';

import '../../shared/models/call_history_entry.dart';
import '../../shared/utils/extensions.dart';
import '../../shared/utils/formatters.dart';

class CallHistoryItem extends StatelessWidget {
  const CallHistoryItem({
    super.key,
    required this.entry,
    required this.onTap,
    required this.locale,
  });

  final CallHistoryEntry entry;
  final VoidCallback onTap;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final missed = entry.result == CallResult.missed;

    final (icon, color) = switch ((entry.direction, entry.result)) {
      (_, CallResult.missed) => (Icons.call_missed, Colors.red),
      (_, CallResult.rejected) => (Icons.call_end, context.colors.outline),
      (_, CallResult.failed) => (Icons.error_outline, context.colors.error),
      (CallDirection.inbound, _) => (Icons.call_received, Colors.green),
      (CallDirection.outbound, _) => (Icons.call_made, context.colors.primary),
    };

    final subtitle = [
      Formatters.dayLabel(
        entry.startedAt,
        locale,
        today: l10n.today,
        yesterday: l10n.yesterday,
      ),
      Formatters.time(entry.startedAt, locale),
      if (entry.result == CallResult.answered)
        Formatters.duration(Duration(seconds: entry.durationSeconds))
      else if (missed)
        l10n.missed
      else if (entry.result == CallResult.rejected)
        l10n.rejected
      else
        l10n.failed,
    ].join(' · ');

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        entry.displayLabel,
        style: missed ? TextStyle(color: context.colors.error) : null,
      ),
      subtitle: Text(subtitle, style: context.texts.bodySmall),
      trailing: IconButton(
        icon: const Icon(Icons.call),
        tooltip: l10n.call,
        onPressed: onTap,
      ),
      onTap: onTap,
    );
  }
}
