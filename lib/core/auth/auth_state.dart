import 'package:meta/meta.dart';

import '../../shared/models/app_exception.dart';
import '../../shared/models/user.dart';

enum AuthStatus {
  initial,
  authenticating,
  authenticated,
  refreshing,
  unauthenticated,
  error,
}

@immutable
class AuthState {
  const AuthState({this.status = AuthStatus.initial, this.user, this.error});

  const AuthState.unauthenticated({this.error})
    : status = AuthStatus.unauthenticated,
      user = null;

  final AuthStatus status;
  final User? user;
  final AppException? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isBusy =>
      status == AuthStatus.authenticating || status == AuthStatus.refreshing;

  /// `true` once the session has been resolved one way or the other — the
  /// splash screen waits for this before routing.
  bool get isResolved => status != AuthStatus.initial;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    AppException? error,
    bool clearError = false,
  }) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    error: clearError ? null : error ?? this.error,
  );
}
