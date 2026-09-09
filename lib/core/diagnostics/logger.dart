import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/env.dart';

enum LogLevel { debug, info, warning, error }

/// Structured logger with mandatory secret redaction.
///
/// Security requirement (PRD 6.8 / 9.2): passwords, bearer tokens, SIP secrets
/// and push tokens must never reach console, log file, or crash reports.
/// Redaction happens here rather than at each call site so a forgotten
/// `log(token)` still cannot leak — the value is scrubbed on the way out.
class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  /// Ring buffer surfaced on the diagnostics screen and attached to support
  /// uploads. Bounded so it cannot grow without limit.
  final Queue<String> _recent = Queue<String>();
  static const int _recentLimit = 300;

  IOSink? _fileSink;

  /// Values registered here are replaced with `***` anywhere they appear.
  final Set<String> _secrets = <String>{};

  static final List<RegExp> _patterns = [
    // key/value credentials, including an inline `Bearer ` prefix so the token
    // after it is consumed rather than left behind.
    RegExp(
      r'("?(?:password|passwd|secret|token|authorization|ha1)"?\s*[:=]\s*)'
      r'"?(?:Bearer\s+)?([^",;\s}]+)"?',
      caseSensitive: false,
    ),
    // Bare bearer tokens with no key in front of them.
    RegExp(r'\bBearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
  ];

  /// Registers a live secret (SIP password, access token) for redaction.
  void registerSecret(String? value) {
    if (value != null && value.length >= 6) _secrets.add(value);
  }

  void clearSecrets() => _secrets.clear();

  @visibleForTesting
  String redact(String input) {
    var out = input;
    for (final secret in _secrets) {
      out = out.replaceAll(secret, '***');
    }
    for (final pattern in _patterns) {
      out = out.replaceAllMapped(
        pattern,
        (m) => m.groupCount >= 2 ? '${m.group(1)}***' : 'Bearer ***',
      );
    }
    return out;
  }

  Future<void> enableFileLogging() async {
    if (_fileSink != null) return;
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/callnusa.log');
    // Keep a single bounded file: truncate once it passes 1 MB.
    if (await file.exists() && await file.length() > 1024 * 1024) {
      await file.writeAsString('');
    }
    _fileSink = file.openWrite(mode: FileMode.append);
  }

  Future<void> dispose() async {
    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;
  }

  List<String> get recentLines => List.unmodifiable(_recent);

  void debug(String tag, String message) => _log(LogLevel.debug, tag, message);
  void info(String tag, String message) => _log(LogLevel.info, tag, message);
  void warn(String tag, String message) => _log(LogLevel.warning, tag, message);

  void error(String tag, String message, [Object? err, StackTrace? stack]) =>
      _log(LogLevel.error, tag, message, err, stack);

  void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? err,
    StackTrace? stack,
  ]) {
    if (level == LogLevel.debug && Env.isProduction) return;

    final line = redact(
      '${DateTime.now().toIso8601String()} '
      '[${level.name.toUpperCase()}] $tag: $message'
      '${err == null ? '' : ' | $err'}',
    );

    _recent.addLast(line);
    while (_recent.length > _recentLimit) {
      _recent.removeFirst();
    }

    _fileSink?.writeln(line);
    developer.log(line, name: tag, level: _levelValue(level));
    if (stack != null && !Env.isProduction) {
      developer.log(stack.toString(), name: tag);
    }
  }

  static int _levelValue(LogLevel l) => switch (l) {
    LogLevel.debug => 500,
    LogLevel.info => 800,
    LogLevel.warning => 900,
    LogLevel.error => 1000,
  };
}

/// Shorthand used throughout the app.
AppLogger get log => AppLogger.instance;
