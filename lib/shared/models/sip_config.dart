import 'package:meta/meta.dart';

enum SipTransport { tls, tcp, udp }

/// SRTP policy handed down by the backend. `mandatory` means a call must fail
/// rather than fall back to unencrypted RTP.
enum SrtpPolicy { mandatory, optional, disabled }

/// Device-scoped SIP credentials and policy from `/api/v1/provisioning/device`.
///
/// [password] is a secret: it is persisted only in secure storage and is
/// deliberately excluded from [toString] and from every log statement.
@immutable
class SipConfig {
  const SipConfig({
    required this.domain,
    required this.username,
    required this.password,
    required this.transport,
    required this.port,
    required this.srtp,
    required this.codecs,
    required this.expiresSeconds,
    this.displayName,
    this.proxyHost,
    this.stunServer,
  });

  final String domain;
  final String username;
  final String password;
  final SipTransport transport;
  final int port;
  final SrtpPolicy srtp;
  final List<String> codecs;
  final int expiresSeconds;
  final String? displayName;

  /// Optional outbound proxy; defaults to [domain] when the backend omits it.
  final String? proxyHost;
  final String? stunServer;

  String get identity => 'sip:$username@$domain';

  String get proxyUri =>
      'sip:${proxyHost ?? domain}:$port;transport=${transport.name}';

  factory SipConfig.fromJson(
    Map<String, dynamic> json, {
    int defaultExpiry = 600,
  }) {
    final transport = SipTransport.values.firstWhere(
      (t) => t.name == (json['transport'] as String? ?? 'tls').toLowerCase(),
      orElse: () => SipTransport.tls,
    );
    return SipConfig(
      domain: json['domain'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      transport: transport,
      port:
          (json['port'] as num?)?.toInt() ??
          (transport == SipTransport.tls ? 5061 : 5060),
      srtp: SrtpPolicy.values.firstWhere(
        (p) => p.name == (json['srtp'] as String? ?? 'mandatory').toLowerCase(),
        orElse: () => SrtpPolicy.mandatory,
      ),
      codecs:
          (json['codecs'] as List?)?.map((c) => '$c').toList() ??
          const ['opus', 'pcmu', 'pcma'],
      expiresSeconds: (json['expires'] as num?)?.toInt() ?? defaultExpiry,
      displayName: json['display_name'] as String?,
      proxyHost: json['proxy'] as String?,
      stunServer: json['stun'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'username': username,
    'password': password,
    'transport': transport.name,
    'port': port,
    'srtp': srtp.name,
    'codecs': codecs,
    'expires': expiresSeconds,
    'display_name': displayName,
    'proxy': proxyHost,
    'stun': stunServer,
  };

  /// Payload handed to the native Liblinphone binding.
  Map<String, dynamic> toNativeConfig() => toJson();

  @override
  String toString() =>
      'SipConfig($identity via ${transport.name}:$port, srtp=${srtp.name}, '
      'codecs=${codecs.join(",")}, password=<redacted>)';
}
