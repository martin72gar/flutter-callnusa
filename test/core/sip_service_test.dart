import 'dart:async';

import 'package:callnusa_mobile/core/sip/linphone_service.dart';
import 'package:callnusa_mobile/core/sip/sip_models.dart';
import 'package:callnusa_mobile/core/sip/sip_service.dart';
import 'package:callnusa_mobile/shared/models/sip_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeBinding implements LinphoneBinding {
  final registration = StreamController<SipRegistrationEvent>.broadcast();
  final calls = StreamController<SipCallEvent>.broadcast();
  final invocations = <String>[];
  SipConfig? appliedConfig;

  @override
  Stream<SipRegistrationEvent> get registrationEvents => registration.stream;

  @override
  Stream<SipCallEvent> get callEvents => calls.stream;

  @override
  Future<void> initialize() async => invocations.add('initialize');

  @override
  Future<void> setAccount(SipConfig config) async {
    invocations.add('setAccount');
    appliedConfig = config;
  }

  @override
  Future<void> clearAccount() async => invocations.add('clearAccount');

  @override
  Future<void> refreshRegistration() async => invocations.add('refresh');

  @override
  Future<void> setNetworkReachable(bool reachable) async =>
      invocations.add('network:$reachable');

  @override
  Future<String> startCall(String destination) async {
    invocations.add('startCall:$destination');
    return 'call-1';
  }

  @override
  Future<void> acceptCall(String callId) async => invocations.add('accept');

  @override
  Future<void> declineCall(String callId) async => invocations.add('decline');

  @override
  Future<void> endCall(String callId) async => invocations.add('end');

  @override
  Future<void> setMuted(String callId, bool muted) async =>
      invocations.add('mute:$muted');

  @override
  Future<void> setHeld(String callId, bool held) async =>
      invocations.add('hold:$held');

  @override
  Future<void> setAudioRoute(AudioRoute route) async =>
      invocations.add('route:${route.name}');

  @override
  Future<void> sendDtmf(String callId, String digit) async =>
      invocations.add('dtmf:$digit');

  @override
  Future<void> dispose() async {
    await registration.close();
    await calls.close();
  }
}

class _MockConnectivity extends Mock implements Connectivity {}

const _config = SipConfig(
  domain: 'sip.callnusa.id',
  username: '1001',
  password: 'secret',
  transport: SipTransport.tls,
  port: 5061,
  srtp: SrtpPolicy.mandatory,
  codecs: ['opus'],
  expiresSeconds: 600,
);

void main() {
  late _FakeBinding binding;
  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> network;
  late int authFailures;
  late SipService sip;

  setUp(() {
    binding = _FakeBinding();
    connectivity = _MockConnectivity();
    network = StreamController<List<ConnectivityResult>>.broadcast();
    authFailures = 0;

    when(
      () => connectivity.onConnectivityChanged,
    ).thenAnswer((_) => network.stream);

    sip = SipService(
      binding,
      connectivity: connectivity,
      onAuthFailure: () async => authFailures++,
    );
  });

  tearDown(() async {
    await network.close();
    await sip.dispose();
  });

  test('applying a config starts the stack and registers', () async {
    await sip.apply(_config);

    expect(binding.invocations, containsAll(['initialize', 'setAccount']));
    expect(binding.appliedConfig, _config);
    expect(sip.status, SipRegistrationStatus.connecting);
  });

  test('tracks registration state from the stack', () async {
    await sip.apply(_config);
    final states = <SipRegistrationStatus>[];
    sip.statusStream.listen(states.add);

    binding.registration.add(
      const SipRegistrationEvent(SipRegistrationStatus.registered),
    );
    await pumpEventQueue();

    expect(sip.status, SipRegistrationStatus.registered);
    expect(states, contains(SipRegistrationStatus.registered));
  });

  test('schedules a retry after a transport failure', () async {
    await sip.apply(_config);
    final retries = <DateTime?>[];
    sip.retryAtStream.listen(retries.add);

    binding.registration.add(
      const SipRegistrationEvent(
        SipRegistrationStatus.failed,
        reason: 'timeout',
      ),
    );
    await pumpEventQueue();

    final scheduled = retries.whereType<DateTime>().toList();
    expect(scheduled, isNotEmpty, reason: 'a retry should have been scheduled');
    // First backoff step is 1s (PRD 6.3).
    expect(
      scheduled.first.difference(DateTime.now()).inMilliseconds,
      lessThanOrEqualTo(1000),
    );
    expect(authFailures, 0);
  });

  test(
    're-provisions instead of retrying when credentials are rejected',
    () async {
      await sip.apply(_config);

      binding.registration.add(
        const SipRegistrationEvent(
          SipRegistrationStatus.failed,
          reason: '403 Forbidden',
          isAuthFailure: true,
        ),
      );
      await pumpEventQueue();

      expect(authFailures, 1);
      expect(binding.invocations, isNot(contains('refresh')));
    },
  );

  test('goes offline on network loss and retries when it returns', () async {
    await sip.apply(_config);

    network.add([ConnectivityResult.none]);
    await pumpEventQueue();
    expect(sip.status, SipRegistrationStatus.unregistered);
    expect(binding.invocations, contains('network:false'));

    network.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(binding.invocations, contains('network:true'));
    expect(binding.invocations, contains('refresh'));
  });

  test('stop unregisters the account', () async {
    await sip.apply(_config);
    await sip.stop();

    expect(binding.invocations, contains('clearAccount'));
    expect(sip.status, SipRegistrationStatus.unregistered);
  });
}
