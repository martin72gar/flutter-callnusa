import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../l10n/app_localizations.dart';
import 'app_lifecycle.dart';
import 'providers.dart';
import 'router.dart';

class CallNusaApp extends ConsumerWidget {
  const CallNusaApp({super.key});

  static const Color _seed = Color(0xFF0B3D91);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageCode = ref.watch(settingsProvider).languageCode;

    return AppLifecycleObserver(
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        routerConfig: ref.watch(routerProvider),
        locale: languageCode == null ? null : Locale(languageCode),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: _seed),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _seed,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
      ),
    );
  }
}
