import 'package:callnusa_mobile/core/diagnostics/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLogger redaction', () {
    setUp(log.clearSecrets);

    test('scrubs registered secrets anywhere in the line', () {
      log.registerSecret('device-scoped-secret');

      expect(
        log.redact('registering with device-scoped-secret now'),
        'registering with *** now',
      );
    });

    test(
      'scrubs credential-shaped key/value pairs it was never told about',
      () {
        expect(log.redact('{"password":"hunter2"}'), contains('***'));
        expect(
          log.redact('{"password":"hunter2"}'),
          isNot(contains('hunter2')),
        );
        expect(log.redact('token=abc123def'), isNot(contains('abc123def')));
      },
    );

    test('scrubs bearer tokens', () {
      final line = log.redact('Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.x');

      expect(line, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
    });

    test('leaves ordinary text alone', () {
      expect(
        log.redact('registration → registered'),
        'registration → registered',
      );
    });
  });
}
