import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_state.dart';
import 'providers.dart';

/// Refreshes provisioning when the app returns to the foreground.
///
/// The backend may have rotated SIP credentials or changed policy while the app
/// was away; [ProvisioningService.fetch] is rate-limited, so app switching
/// cannot turn this into a request flood.
class AppLifecycleObserver extends ConsumerStatefulWidget {
  const AppLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleObserver> createState() =>
      _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final auth = ref.read(authStateProvider).value ?? const AuthState();
    if (!auth.isAuthenticated) return;
    ref.read(provisioningServiceProvider).fetch();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
