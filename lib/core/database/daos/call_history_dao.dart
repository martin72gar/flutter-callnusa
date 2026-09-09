import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../../config/constants.dart';
import '../../../shared/models/call_history_entry.dart';

/// Local call-history cache, newest first.
class CallHistoryDao {
  CallHistoryDao(this._box);

  final Box<dynamic> _box;

  /// Emits on every mutation so the UI can be a plain stream listener.
  Stream<List<CallHistoryEntry>> watch() async* {
    yield all();
    yield* _box.watch().map((_) => all());
  }

  List<CallHistoryEntry> all() {
    final entries =
        _box.values
            .map(
              (v) =>
                  CallHistoryEntry.fromJson((v as Map).cast<String, dynamic>()),
            )
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return entries;
  }

  List<CallHistoryEntry> filtered(HistoryFilter filter) =>
      all().where((e) => e.matches(filter)).toList();

  Future<void> upsert(CallHistoryEntry entry) async {
    await _box.put(entry.id, entry.toJson());
    await _trim();
  }

  /// Merges a server page into the cache. Server rows win over local ones with
  /// the same id, so a synced call stops being marked [CallHistoryEntry.isLocal].
  Future<void> upsertAll(Iterable<CallHistoryEntry> entries) async {
    await _box.putAll({for (final e in entries) e.id: e.toJson()});
    await _trim();
  }

  Future<void> clear() => _box.clear();

  Future<void> _trim() async {
    final overflow = _box.length - AppConstants.localHistoryLimit;
    if (overflow <= 0) return;
    final oldest = all().reversed.take(overflow).map((e) => e.id);
    await _box.deleteAll(oldest);
  }
}
