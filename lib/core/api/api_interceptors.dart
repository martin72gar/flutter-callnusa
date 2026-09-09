import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../shared/models/app_exception.dart';
import '../diagnostics/logger.dart';
import '../secure_storage/secure_storage_service.dart';
import 'api_endpoints.dart';

/// Adds the identifying headers every authenticated endpoint expects.
class ClientHeadersInterceptor extends Interceptor {
  ClientHeadersInterceptor({
    required this.storage,
    required this.platform,
    required this.appVersion,
  });

  final SecureStorageService storage;
  final String platform;
  final String appVersion;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers.addAll({
      'Accept': 'application/json',
      'X-Client-Platform': platform,
      'X-Client-Version': appVersion,
      'X-Device-Id': await storage.deviceId(),
    });
    if (options.extra['skipAuth'] != true) {
      final token = await storage.accessToken;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Refreshes an expired access token once, then replays the original request.
///
/// Concurrent 401s share a single refresh call via [_refreshing]; without that
/// a burst of parallel requests would each burn a refresh token and the
/// backend would invalidate the session.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.storage,
    required this.baseUrl,
    required this.onSessionExpired,
    Dio? refreshClient,
  }) : _refreshClient = refreshClient ?? Dio(BaseOptions(baseUrl: baseUrl));

  final SecureStorageService storage;
  final String baseUrl;
  final Future<void> Function() onSessionExpired;
  final Dio _refreshClient;

  Future<_RefreshOutcome>? _refreshing;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isAuthEndpoint =
        options.path.contains(ApiEndpoints.refresh) ||
        options.path.contains(ApiEndpoints.login);

    if (err.response?.statusCode != 401 ||
        isAuthEndpoint ||
        options.extra['retried'] == true) {
      return handler.next(err);
    }

    final refreshed = await (_refreshing ??= _refresh());
    _refreshing = null;

    if (refreshed != _RefreshOutcome.ok) {
      // A transient network failure must not sign the user out; only a
      // rejected refresh token (INVALID_REFRESH_TOKEN) ends the session.
      if (refreshed == _RefreshOutcome.rejected) await onSessionExpired();
      return handler.next(err);
    }

    try {
      options.extra['retried'] = true;
      final token = await storage.accessToken;
      options.headers['Authorization'] = 'Bearer $token';
      final response = await _refreshClient.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  Future<_RefreshOutcome> _refresh() async {
    final refreshToken = await storage.refreshToken;
    if (refreshToken == null) return _RefreshOutcome.rejected;
    try {
      final response = await _refreshClient.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refresh_token': refreshToken},
      );
      final data =
          (response.data?['data'] ?? response.data) as Map<String, dynamic>;
      await storage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String?,
      );
      log.info('api', 'access token refreshed');
      return _RefreshOutcome.ok;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      log.warn('api', 'token refresh failed: http $status');
      // 401 = INVALID_REFRESH_TOKEN (single-use token already consumed or
      // expired). Anything else (timeout, 5xx) is retried on the next 401.
      return status == 401
          ? _RefreshOutcome.rejected
          : _RefreshOutcome.transient;
    } catch (e) {
      log.warn('api', 'token refresh failed: $e');
      return _RefreshOutcome.transient;
    }
  }
}

enum _RefreshOutcome { ok, rejected, transient }

/// Converts Dio failures into [AppException] so no layer above the API client
/// has to know about Dio.
class ErrorMappingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: mapError(err),
      ),
    );
  }

  static AppException mapError(DioException err) {
    final status = err.response?.statusCode;
    final body = err.response?.data;
    final error = body is Map ? body['error'] : null;
    final code = error is Map ? error['code'] as String? : null;

    final kind = switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => AppErrorKind.timeout,
      DioExceptionType.connectionError => AppErrorKind.network,
      _ when err.error is SocketException => AppErrorKind.network,
      _ => switch (status ?? 0) {
        401 => AppErrorKind.unauthorized,
        403 => AppErrorKind.forbidden,
        404 => AppErrorKind.notFound,
        422 => AppErrorKind.validation,
        429 => AppErrorKind.rateLimited,
        >= 500 => AppErrorKind.server,
        _ => AppErrorKind.unknown,
      },
    };

    return AppException(
      kind,
      code: code,
      statusCode: status,
      message: error is Map ? error['message'] as String? : null,
      details: error is Map
          ? (error['details'] as Map?)?.cast<String, dynamic>() ?? const {}
          : const {},
      correlationId: err.response?.headers.value('x-correlation-id'),
    );
  }
}

/// Request/response logging. Bodies are never logged — provisioning responses
/// carry the SIP password (PRD 6.2).
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    log.debug('api', '→ ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    log.debug(
      'api',
      '← ${response.statusCode} ${response.requestOptions.path}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final cid = err.response?.headers.value('x-correlation-id');
    log.warn(
      'api',
      '✗ ${err.response?.statusCode ?? err.type.name} '
          '${err.requestOptions.path}${cid == null ? '' : ' cid=$cid'}',
    );
    handler.next(err);
  }
}
