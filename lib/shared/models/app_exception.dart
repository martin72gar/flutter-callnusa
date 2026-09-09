/// Error categories the UI knows how to talk about (PRD 6.8).
enum AppErrorKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  rateLimited,
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
  const AppException(
    this.kind, {
    this.code,
    this.message,
    this.statusCode,
    this.details = const {},
    this.correlationId,
  });

  final AppErrorKind kind;
  final String? code;
  final String? message;
  final int? statusCode;

  /// Field-level validation errors (`error.details`), keyed by field name.
  final Map<String, dynamic> details;

  /// `X-Correlation-ID` of the failing response; quote it in bug reports so
  /// it can be matched against server logs.
  final String? correlationId;

  bool get isRetryable =>
      kind == AppErrorKind.network ||
      kind == AppErrorKind.timeout ||
      kind == AppErrorKind.server;

  @override
  String toString() =>
      'AppException(${kind.name}${code == null ? '' : ', $code'}'
      '${statusCode == null ? '' : ', http $statusCode'}'
      '${correlationId == null ? '' : ', cid=$correlationId'})';
}
