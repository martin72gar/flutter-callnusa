import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/call_history/call_history_screen.dart';
import '../features/dialer/dialer_screen.dart';
import '../features/settings/settings_screen.dart';
import '../shared/utils/extensions.dart';
import '../shared/widgets/registration_badge.dart';

/// Signed-in shell: dialer, history, settings.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final titles = [l10n.appName, l10n.historyTitle, l10n.settingsTitle];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: const [RegistrationBadge(), SizedBox(width: 8)],
      ),
      body: IndexedStack(
        index: _index,
        children: const [DialerScreen(), CallHistoryScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dialpad),
            label: l10n.tabDialer,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: l10n.tabHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings),
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}
