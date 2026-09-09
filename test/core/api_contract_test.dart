// Pins the app's parsing to the live backend's response shapes (verified with
// curl against laravel-callnusa on 2026-09-09).
import 'package:callnusa_mobile/core/api/api_interceptors.dart';
import 'package:callnusa_mobile/shared/models/app_exception.dart';
import 'package:callnusa_mobile/shared/models/call_history_entry.dart';
import 'package:callnusa_mobile/shared/models/device.dart';
import 'package:callnusa_mobile/shared/models/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GET /me uses the public UUID, not the integer id', () {
    final user = User.fromJson({
      'id': 3,
      'public_id': '871ade89-5899-4de3-8a5b-a737722d31cd',
      'name': 'Agent',
      'email': 'acme1-agent1@callnusa.test',
      'role': 'agent',
      'status': 'active',
    });
    expect(user.id, '871ade89-5899-4de3-8a5b-a737722d31cd');
    expect(user.isAdmin, isFalse);
  });

  test('GET /calls row maps to a history entry', () {
    final entry = CallHistoryEntry.fromApi({
      'id': 9,
      'public_id': 'c1',
      'direction': 'inbound',
      'source': '+628111',
      'destination': '1001',
      'status': 'missed',
      'started_at': '2026-09-09T10:00:00.000000Z',
      'answered_at': null,
      'ended_at': '2026-09-09T10:00:20.000000Z',
      'duration': 0,
    });
    expect(entry.id, 'c1');
    expect(entry.counterpartyNumber, '+628111');
    expect(entry.result, CallResult.missed);
    expect(entry.isLocal, isFalse);
  });

  test('PUT /devices/current body uses the backend field names', () {
    final body = const DeviceRegistration(
      deviceUid: 'u',
      platform: 'android',
      appVersion: '1.0.0+1',
      pushToken: 't',
    ).toJson();
    expect(body.keys, ['device_uid', 'platform', 'app_version', 'push_token']);
  });

  test('error envelope maps code, details, 429 and correlation id', () {
    final req = RequestOptions(path: '/api/v1/auth/login');
    final e = ErrorMappingInterceptor.mapError(
      DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: req,
          statusCode: 429,
          headers: Headers.fromMap({
            'x-correlation-id': ['cid-1'],
          }),
          data: {
            'error': {
              'code': 'RATE_LIMITED',
              'message': 'Too Many Requests',
              'details': {'email': ['bad']},
            },
          },
        ),
      ),
    );
    expect(e.kind, AppErrorKind.rateLimited);
    expect(e.code, 'RATE_LIMITED');
    expect(e.details['email'], ['bad']);
    expect(e.correlationId, 'cid-1');
  });
}
