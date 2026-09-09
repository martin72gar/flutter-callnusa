import '../../config/constants.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/database/daos/call_history_dao.dart';
import '../../core/diagnostics/logger.dart';
import '../../shared/models/app_exception.dart';
import '../../shared/models/call_history_entry.dart';

/// Merges the server CDR into the local cache.
///
/// The backend is authoritative, but the cache is what the UI renders — so a
/// sync failure degrades to "slightly stale list", never to an empty screen.
class CallHistoryRepository {
  CallHistoryRepository(this._api, this._dao);

  final ApiClient _api;
  final CallHistoryDao _dao;

  Future<void> sync({HistoryFilter filter = HistoryFilter.all}) async {
    try {
      final response = await _api.get(
        ApiEndpoints.calls,
        // The backend has no filter param; filtering is local (matches()).
        query: {'per_page': AppConstants.historyPageSize},
      );
      final rows = (response['data'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CallHistoryEntry.fromApi);
      await _dao.upsertAll(rows);
      log.info('history', 'synced ${rows.length} entries');
    } on AppException catch (e) {
      log.warn('history', 'sync failed, keeping local cache: $e');
    }
  }
}
