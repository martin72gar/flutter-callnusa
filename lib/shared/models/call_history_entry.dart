import 'package:meta/meta.dart';

enum CallDirection { inbound, outbound }

enum CallResult { answered, missed, rejected, failed }

enum HistoryFilter { all, missed, inbound, outbound }

@immutable
class CallHistoryEntry {
  const CallHistoryEntry({
    required this.id,
    required this.direction,
    required this.counterpartyNumber,
    required this.result,
    required this.startedAt,
    this.counterpartyName,
    this.answeredAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.isLocal = true,
  });

  final String id;
  final CallDirection direction;
  final String? counterpartyName;
  final String counterpartyNumber;
  final CallResult result;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int durationSeconds;

  /// `true` while the entry exists only on this device (not yet in the CDR).
  final bool isLocal;

  String get displayLabel =>
      (counterpartyName?.trim().isNotEmpty ?? false) &&
          counterpartyName != counterpartyNumber
      ? counterpartyName!
      : counterpartyNumber;

  bool matches(HistoryFilter filter) => switch (filter) {
    HistoryFilter.all => true,
    HistoryFilter.missed => result == CallResult.missed,
    HistoryFilter.inbound => direction == CallDirection.inbound,
    HistoryFilter.outbound => direction == CallDirection.outbound,
  };

  CallHistoryEntry copyWith({
    CallResult? result,
    DateTime? answeredAt,
    DateTime? endedAt,
    int? durationSeconds,
    bool? isLocal,
    String? counterpartyName,
  }) => CallHistoryEntry(
    id: id,
    direction: direction,
    counterpartyNumber: counterpartyNumber,
    counterpartyName: counterpartyName ?? this.counterpartyName,
    result: result ?? this.result,
    startedAt: startedAt,
    answeredAt: answeredAt ?? this.answeredAt,
    endedAt: endedAt ?? this.endedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    isLocal: isLocal ?? this.isLocal,
  );

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) =>
      CallHistoryEntry(
        id: '${json['id']}',
        direction: CallDirection.values.firstWhere(
          (d) => d.name == json['direction'],
          orElse: () => CallDirection.inbound,
        ),
        counterpartyNumber: json['counterparty_number'] as String? ?? '',
        counterpartyName: json['counterparty_name'] as String?,
        result: CallResult.values.firstWhere(
          (s) => s.name == (json['status'] ?? json['result']),
          orElse: () => CallResult.failed,
        ),
        startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
        answeredAt: json['answered_at'] == null
            ? null
            : DateTime.parse(json['answered_at'] as String).toLocal(),
        endedAt: json['ended_at'] == null
            ? null
            : DateTime.parse(json['ended_at'] as String).toLocal(),
        durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
        isLocal: json['is_local'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'direction': direction.name,
    'counterparty_number': counterpartyNumber,
    'counterparty_name': counterpartyName,
    'status': result.name,
    'started_at': startedAt.toUtc().toIso8601String(),
    'answered_at': answeredAt?.toUtc().toIso8601String(),
    'ended_at': endedAt?.toUtc().toIso8601String(),
    'duration_seconds': durationSeconds,
    'is_local': isLocal,
  };
}
