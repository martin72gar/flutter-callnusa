/// Error categories the UI knows how to talk about (PRD 6.8).
enum AppErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  server,
  provisioning,
  sip,
  platform,
  unknown,
}

/// A failure with a machine-readable [code] for logic and a [kind] the
/// presentation layer maps to a localized, user-friendly message.
///
/// Never carries secrets: only backend error codes and safe detail values.
class AppException implements Exception {
  const AppException(this.kind, {this.code, this.message, this.statusCode});

  final AppErrorKind kind;
  final String? code;
  final String? message;
  final int? statusCode;

  bool get isRetryable =>
      kind == AppErrorKind.network ||
      kind == AppErrorKind.timeout ||
      kind == AppErrorKind.server;

  @override
  String toString() =>
      'AppException(${kind.name}${code == null ? '' : ', $code'}'
      '${statusCode == null ? '' : ', http $statusCode'})';
}
