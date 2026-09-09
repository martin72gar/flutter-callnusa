import 'dart:async';

import '../../features/provisioning/provisioning_service.dart';
import '../../shared/models/app_exception.dart';
import '../database/app_database.dart';
import '../diagnostics/logger.dart';
import '../notification/callkit_service.dart';
import '../notification/push_service.dart';
import '../secure_storage/secure_storage_service.dart';
import '../sip/sip_service.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

/// Session lifecycle: sign in, restore, and sign out.
///
/// Owns the ordering of the side effects that must accompany each transition —
/// provisioning, SIP registration, push registration, and the cleanup that has
/// to happen on the way out.
class AuthService {
  AuthService({
    required this._repository,
    required this._storage,
    required this._provisioning,
    required this._sip,
    required this._push,
    required this._callKit,
    required this._database,
  });

  final AuthRepository _repository;
  final SecureStorageService _storage;
  final ProvisioningService _provisioning;
  final SipService _sip;
  final PushService _push;
  final CallKitService _callKit;
  final AppDatabase _database;

  final _controller = StreamController<AuthState>.broadcast();
  AuthState _state = const AuthState();

  AuthState get state => _state;
  Stream<AuthState> get stream => _controller.stream;

  /// Called on app start. Registers SIP from cached credentials first so an
  /// incoming call can land while provisioning refreshes in the background.
  Future<void> restore() async {
    if (!await _repository.hasSession()) {
      _emit(const AuthState.unauthenticated());
      return;
    }
    final user = await _repository.cachedUser();
    _emit(AuthState(status: AuthStatus.authenticated, user: user));

    await _startSession(useCache: true);
  }

  Future<void> login({required String email, required String password}) async {
    _emit(_state.copyWith(status: AuthStatus.authenticating, clearError: true));
    try {
      final result = await _repository.login(email: email, password: password);
      _emit(AuthState(status: AuthStatus.authenticated, user: result.user));
      await _startSession(useCache: false);
    } on AppException catch (e) {
      log.warn('auth', 'login failed: $e');
      _emit(AuthState(status: AuthStatus.error, error: e));
    }
  }

  Future<void> _startSession({required bool useCache}) async {
    _callKit.start();
    if (useCache) await _provisioning.applyCachedConfig();
    await _provisioning.fetch(force: !useCache);
    await _push.start();
  }

  /// Signals from the API layer that the refresh token is no longer valid.
  Future<void> onSessionExpired() async {
    if (_state.status == AuthStatus.unauthenticated) return;
    log.warn('auth', 'session expired, signing out');
    await _teardown();
    _emit(
      const AuthState.unauthenticated(
        error: AppException(
          AppErrorKind.unauthorized,
          code: 'AUTH_SESSION_EXPIRED',
        ),
      ),
    );
  }

  Future<void> logout() async {
    await _repository.revokeSession();
    await _teardown();
    _emit(const AuthState.unauthenticated());
  }

  /// Everything that must be undone when a session ends (PRD 6.7).
  Future<void> _teardown() async {
    await _callKit.endAll();
    await _sip.stop();
    await _provisioning.clear();
    await _push.deleteToken();
    await _database.clearUserData();
    await _storage.clearSession();
  }

  void _emit(AuthState state) {
    _state = state;
    _controller.add(state);
  }

  Future<void> dispose() => _controller.close();
}
