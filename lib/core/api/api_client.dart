import 'dart:io';

import 'package:dio/dio.dart';

import '../../config/env.dart';
import '../../shared/models/app_exception.dart';
import '../secure_storage/secure_storage_service.dart';
import 'api_interceptors.dart';

/// Thin Dio wrapper. Every repository talks to the backend through this class,
/// which guarantees consistent headers, auth refresh and error mapping.
class ApiClient {
  ApiClient({
    required SecureStorageService storage,
    required String appVersion,
    required Future<void> Function() onSessionExpired,
    Dio? dio,
  }) : dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: Env.apiBaseUrl,
               connectTimeout: Duration(milliseconds: Env.apiTimeoutMs),
               receiveTimeout: Duration(milliseconds: Env.apiTimeoutMs),
               contentType: Headers.jsonContentType,
               // 4xx/5xx must surface as errors so the interceptors can act.
               validateStatus: (s) => s != null && s >= 200 && s < 300,
             ),
           ) {
    this.dio.interceptors.addAll([
      ClientHeadersInterceptor(
        storage: storage,
        platform: Platform.isIOS ? 'ios' : 'android',
        appVersion: appVersion,
      ),
      AuthInterceptor(
        storage: storage,
        baseUrl: Env.apiBaseUrl,
        onSessionExpired: onSessionExpired,
      ),
      LoggingInterceptor(),
      ErrorMappingInterceptor(),
    ]);
  }

  final Dio dio;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _guard(() => dio.get<Map<String, dynamic>>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool skipAuth = false,
  }) => _guard(
    () => dio.post<Map<String, dynamic>>(
      path,
      data: body,
      options: Options(extra: {'skipAuth': skipAuth}),
    ),
  );

  Future<Map<String, dynamic>> put(String path, {Object? body}) =>
      _guard(() => dio.put<Map<String, dynamic>>(path, data: body));

  Future<Map<String, dynamic>> _guard(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) async {
    try {
      final response = await request();
      return response.data ?? const {};
    } on DioException catch (e) {
      throw e.error is AppException
          ? e.error! as AppException
          : ErrorMappingInterceptor.mapError(e);
    }
  }
}
