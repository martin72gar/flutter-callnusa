import 'package:callnusa_mobile/shared/models/call_history_entry.dart';
import 'package:callnusa_mobile/shared/models/provisioning_config.dart';
import 'package:callnusa_mobile/shared/models/sip_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProvisioningConfig', () {
    const response = {
      'data': {
        'account': {
          'id': 'ext_8f4f24d1',
          'display_name': 'Agent CallNusa',
          'extension': '1001',
        },
        'sip': {
          'domain': 'sip.example.callnusa.id',
          'username': '1001',
          'password': 'device-scoped-secret',
          'transport': 'tls',
          'port': 5061,
          'srtp': 'mandatory',
          'codecs': ['opus', 'pcmu', 'pcma'],
        },
        'features': {'outbound_calling': true, 'video': false},
        'policy': {'default_speaker': false, 'max_registered_devices': 2},
      },
    };

    test('parses the documented payload', () {
      final config = ProvisioningConfig.fromJson(response, defaultExpiry: 600);

      expect(config.account.extension, '1001');
      expect(config.sip.transport, SipTransport.tls);
      expect(config.sip.srtp, SrtpPolicy.mandatory);
      expect(config.sip.expiresSeconds, 600);
      expect(config.sip.identity, 'sip:1001@sip.example.callnusa.id');
      expect(
        config.sip.proxyUri,
        'sip:sip.example.callnusa.id:5061;transport=tls',
      );
      expect(config.features.outboundCalling, isTrue);
    });

    test('defaults to the secure transport when the backend omits fields', () {
      final config = SipConfig.fromJson({
        'domain': 'sip.callnusa.id',
        'username': '1002',
        'password': 's3cret-value',
      });

      expect(config.transport, SipTransport.tls);
      expect(config.port, 5061);
      expect(config.srtp, SrtpPolicy.mandatory);
      expect(config.codecs, ['opus', 'pcmu', 'pcma']);
    });

    // The SIP password must not leak through logs or error reports, and
    // toString() is the most likely accidental route.
    test('never prints the SIP password', () {
      final config = ProvisioningConfig.fromJson(response);

      expect(config.toString(), isNot(contains('device-scoped-secret')));
      expect(config.sip.toString(), contains('<redacted>'));
    });
  });

  group('CallHistoryEntry', () {
    CallHistoryEntry entry(CallDirection direction, CallResult result) =>
        CallHistoryEntry(
          id: '1',
          direction: direction,
          counterpartyNumber: '1001',
          result: result,
          startedAt: DateTime(2026, 1, 1),
        );

    test('filters by direction and missed status', () {
      final missedInbound = entry(CallDirection.inbound, CallResult.missed);
      final answeredOutbound = entry(
        CallDirection.outbound,
        CallResult.answered,
      );

      expect(missedInbound.matches(HistoryFilter.missed), isTrue);
      expect(missedInbound.matches(HistoryFilter.inbound), isTrue);
      expect(missedInbound.matches(HistoryFilter.outbound), isFalse);
      expect(answeredOutbound.matches(HistoryFilter.missed), isFalse);
      expect(answeredOutbound.matches(HistoryFilter.all), isTrue);
    });

    test('round-trips through JSON', () {
      final original = CallHistoryEntry(
        id: 'abc',
        direction: CallDirection.outbound,
        counterpartyNumber: '2002',
        counterpartyName: 'Support',
        result: CallResult.answered,
        startedAt: DateTime(2026, 3, 4, 10, 30),
        answeredAt: DateTime(2026, 3, 4, 10, 30, 5),
        durationSeconds: 42,
      );

      final restored = CallHistoryEntry.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.direction, original.direction);
      expect(restored.result, original.result);
      expect(restored.durationSeconds, 42);
      expect(restored.startedAt, original.startedAt);
    });
  });
}
