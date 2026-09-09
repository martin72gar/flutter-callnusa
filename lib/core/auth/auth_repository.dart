import '../../shared/models/user.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../diagnostics/logger.dart';
import '../secure_storage/secure_storage_service.dart';

class LoginResult {
  const LoginResult(this.user);

  final User user;
}

/// Talks to the auth endpoints and persists the resulting session. Tokens are
/// written straight into secure storage and are never returned to callers, so
/// no other layer can accidentally hold or log them.
class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final SecureStorageService _storage;

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
      skipAuth: true,
    );
    final data = (response['data'] ?? response) as Map<String, dynamic>;

    await _storage.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String?,
    );

    // Login returns tokens only; the user (role, tenant) comes from /me.
    final me = await _api.get(ApiEndpoints.me);
    final user = User.fromJson((me['data'] as Map).cast<String, dynamic>());
    await _storage.saveUser(user);
    log.info('auth', 'login succeeded for user ${user.id}');
    return LoginResult(user);
  }

  /// Always succeeds server-side (no account enumeration); the reset link is
  /// delivered by email.
  Future<void> forgotPassword(String email) => _api.post(
    ApiEndpoints.forgotPassword,
    body: {'email': email},
    skipAuth: true,
  );

  /// Best-effort session revocation. A failure here must not block logout:
  /// local credentials are cleared either way.
  Future<void> revokeSession() async {
    try {
      await _api.post(ApiEndpoints.logout);
    } catch (e) {
      log.warn('auth', 'remote logout failed, clearing locally anyway: $e');
    }
  }

  Future<User?> cachedUser() => _storage.readUser();

  Future<bool> hasSession() async => await _storage.accessToken != null;
}
