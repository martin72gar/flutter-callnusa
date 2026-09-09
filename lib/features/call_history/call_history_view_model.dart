import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../shared/models/call_history_entry.dart';
import 'call_history_repository.dart';

final callHistoryRepositoryProvider = Provider<CallHistoryRepository>(
  (ref) => CallHistoryRepository(
    ref.watch(apiClientProvider),
    ref.watch(callHistoryDaoProvider),
  ),
);

/// The list actually rendered: local cache filtered by the active tab.
final filteredHistoryProvider = Provider<List<CallHistoryEntry>>((ref) {
  final entries = ref.watch(callHistoryProvider).value ?? const [];
  final filter = ref.watch(historyFilterProvider);
  return entries.where((e) => e.matches(filter)).toList();
});
