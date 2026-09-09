import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

  /// `m:ss` under an hour, `h:mm:ss` beyond it.
  static String duration(Duration d) {
    final seconds = d.inSeconds.abs();
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
    return h > 0
        ? '$h:$mm:${s.toString().padLeft(2, '0')}'
        : '$mm:${s.toString().padLeft(2, '0')}';
  }

  static String time(DateTime at, String locale) =>
      DateFormat.Hm(locale).format(at);

  static String date(DateTime at, String locale) =>
      DateFormat.yMMMd(locale).format(at);

  /// Day header for the history list: "Today" / "Yesterday" / a date.
  static String dayLabel(
    DateTime at,
    String locale, {
    required String today,
    required String yesterday,
  }) {
    final now = DateTime.now();
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(at.year, at.month, at.day)).inDays;
    return switch (days) {
      0 => today,
      1 => yesterday,
      _ => date(at, locale),
    };
  }
}
