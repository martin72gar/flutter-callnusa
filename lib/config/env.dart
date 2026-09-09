import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Build flavor, selected at compile time: `--dart-define=FLAVOR=staging`.
enum Flavor { development, staging, production }

/// Environment configuration.
///
/// Values live in `.env.<flavor>` files that contain **public** configuration
/// only (base URLs, feature switches). Secrets never live here — SIP passwords
/// and auth tokens come from the provisioning API and go straight into secure
/// storage.
class Env {
  const Env._();

  static const String _flavorName = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'development',
  );

  static Flavor _flavor = Flavor.values.firstWhere(
    (f) => f.name == _flavorName,
    orElse: () => Flavor.development,
  );

  static Flavor get flavor => _flavor;

  static bool get isProduction => flavor == Flavor.production;

  /// Loads `.env.<flavor>` and validates the values the app cannot run without.
  ///
  /// The flavor comes from the entrypoint (`main_staging.dart`) or, when the
  /// default entrypoint is used, from `--dart-define=FLAVOR=...`.
  static Future<void> load([Flavor? flavor]) async {
    if (flavor != null) _flavor = flavor;
    await dotenv.load(fileName: '.env.${_flavor.name}');
    _validate();
  }

  static String _require(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing required env key "$key" in .env.${flavor.name}',
      );
    }
    return value;
  }

  static bool _flag(String key, {bool fallback = false}) =>
      switch (dotenv.maybeGet(key)?.toLowerCase()) {
        'true' || '1' || 'yes' => true,
        'false' || '0' || 'no' => false,
        _ => fallback,
      };

  static int _int(String key, int fallback) =>
      int.tryParse(dotenv.maybeGet(key) ?? '') ?? fallback;

  static String get apiBaseUrl => _require('API_BASE_URL');
  static String get sourceRepositoryUrl => _require('SOURCE_REPOSITORY_URL');
  static String get userAgent =>
      dotenv.maybeGet('SIP_USER_AGENT') ?? 'CallNusa';

  /// Registration expiry hint; the backend policy still wins when it sends one.
  static int get sipRegisterExpiry => _int('SIP_REGISTER_EXPIRY_SECONDS', 600);
  static int get apiTimeoutMs => _int('API_TIMEOUT_MS', 15000);

  /// Escape hatch for local development against a plaintext backend.
  /// Ignored in production builds — see [_validate].
  static bool get allowInsecureTransport =>
      !isProduction && _flag('ALLOW_INSECURE_TRANSPORT');

  static bool get verboseSipLogging =>
      !isProduction && _flag('SIP_VERBOSE_LOGGING');

  static void _validate() {
    final url = Uri.tryParse(apiBaseUrl);
    if (url == null || !url.hasAuthority) {
      throw StateError('API_BASE_URL is not a valid URL: $apiBaseUrl');
    }
    // Security requirement: production traffic is HTTPS-only (PRD 10.2).
    if (url.scheme != 'https' && !allowInsecureTransport) {
      throw StateError(
        'API_BASE_URL must use https (set ALLOW_INSECURE_TRANSPORT=true for '
        'local non-production development only)',
      );
    }
  }
}
