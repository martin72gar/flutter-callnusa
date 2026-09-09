import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../shared/models/app_exception.dart';
import '../../shared/models/call_history_entry.dart';
import '../../shared/utils/error_messages.dart';
import '../../shared/utils/extensions.dart';
import 'call_history_item_widget.dart';
import 'call_history_view_model.dart';

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget: the UI renders from the local cache either way.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(callHistoryRepositoryProvider).sync(),
    );
  }

  Future<void> _redial(CallHistoryEntry entry) async {
    try {
      await ref
          .read(activeCallProvider.notifier)
          .startCall(
            entry.counterpartyNumber,
            displayName: entry.counterpartyName,
          );
    } on AppException catch (e) {
      if (mounted) context.showSnack(messageFor(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = ref.watch(filteredHistoryProvider);
    final filter = ref.watch(historyFilterProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            spacing: 8,
            children: [
              for (final option in HistoryFilter.values)
                ChoiceChip(
                  selected: filter == option,
                  label: Text(switch (option) {
                    HistoryFilter.all => l10n.filterAll,
                    HistoryFilter.missed => l10n.filterMissed,
                    HistoryFilter.inbound => l10n.filterInbound,
                    HistoryFilter.outbound => l10n.filterOutbound,
                  }),
                  onSelected: (_) =>
                      ref.read(historyFilterProvider.notifier).select(option),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(callHistoryRepositoryProvider).sync(filter: filter),
            child: entries.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Text(
                          l10n.historyEmpty,
                          style: context.texts.bodyLarge?.copyWith(
                            color: context.colors.outline,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => CallHistoryItem(
                      entry: entries[index],
                      locale: locale,
                      onTap: () => _redial(entries[index]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
