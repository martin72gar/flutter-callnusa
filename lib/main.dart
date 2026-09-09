import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/providers.dart';
import 'config/env.dart';
import 'core/diagnostics/logger.dart';
import 'core/notification/push_service.dart';

/// Shared entrypoint for every flavor. `main_<flavor>.dart` passes the flavor
/// explicitly; running this file directly falls back to `--dart-define=FLAVOR`.
Future<void> runCallNusa({Flavor? flavor}) async {
  // Needed before any platform channel call (Firebase below); AppDependencies
  // .create() also calls this, but ensureInitialized() is idempotent.
  WidgetsFlutterBinding.ensureInitialized();

  // Push is optional: a build without Firebase configuration still works in the
  // foreground, it just cannot be woken for incoming calls. This must run
  // before AppDependencies.create(), which constructs a PushService that
  // touches FirebaseMessaging.instance.
  try {
    await PushService.initializeFirebase();
  } catch (e) {
    log.warn('boot', 'Firebase unavailable, push disabled: $e');
  }

  final deps = await AppDependencies.create(flavor: flavor);

  // Restore in the background so the first frame is not blocked on I/O.
  unawaited(deps.auth.restore());

  runApp(
    ProviderScope(
      overrides: [dependenciesProvider.overrideWithValue(deps)],
      child: const CallNusaApp(),
    ),
  );
}

Future<void> main() => runCallNusa();
