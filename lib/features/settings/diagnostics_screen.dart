import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/diagnostics/logger.dart';
import '../../shared/utils/extensions.dart';

/// Read-only support view. The lines shown here have already passed through
/// the logger's redaction, so no secret can reach the screen or a screenshot.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(sipStatusProvider).value;
    final provisioning = ref.watch(provisioningStateProvider);
    final lines = log.recentLines.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.diagnostics)),
      body: Column(
        children: [
          ListTile(
            dense: true,
            title: const Text('SIP registration'),
            trailing: Text(status?.name ?? '—'),
          ),
          ListTile(
            dense: true,
            title: Text(
              context.l10n.extensionLabel(provisioning.extension ?? '—'),
            ),
            trailing: Text(provisioning.status.name),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: lines.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                child: SelectableText(
                  lines[i],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
