import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../config/constants.dart';
import '../../config/env.dart';
import '../../shared/utils/extensions.dart';
import 'diagnostics_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(authServiceProvider).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final user = ref.watch(authStateProvider).value?.user;
    final extension = ref.watch(provisioningStateProvider).extension;

    return ListView(
      children: [
        if (user != null)
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(user.name.isEmpty ? user.email : user.name),
            subtitle: Text(
              extension == null
                  ? user.email
                  : '${user.email} · ${l10n.extensionLabel(extension)}',
            ),
          ),
        _SectionHeader(l10n.sectionAudio),
        SwitchListTile(
          title: Text(l10n.defaultSpeaker),
          value: settings.defaultSpeaker,
          onChanged: controller.setDefaultSpeaker,
        ),
        SwitchListTile(
          title: Text(l10n.autoAnswer),
          value: settings.autoAnswer,
          onChanged: controller.setAutoAnswer,
        ),
        _SectionHeader(l10n.sectionNotifications),
        SwitchListTile(
          title: Text(l10n.vibrate),
          value: settings.vibrate,
          onChanged: controller.setVibrate,
        ),
        ListTile(
          title: Text(l10n.ringtone),
          subtitle: Text(settings.ringtone),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pickRingtone(context, ref),
        ),
        ListTile(
          title: Text(l10n.language),
          subtitle: Text(switch (settings.languageCode) {
            'id' => 'Bahasa Indonesia',
            'en' => 'English',
            _ => l10n.languageSystem,
          }),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pickLanguage(context, ref),
        ),
        _SectionHeader(l10n.sectionAbout),
        ListTile(
          title: Text(l10n.appVersion),
          subtitle: Text(
            '${ref.watch(appVersionProvider)} (${Env.flavor.name})',
          ),
        ),
        ListTile(
          title: Text(l10n.license),
          subtitle: Text(l10n.licenseGpl),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _open('https://www.gnu.org/licenses/gpl-3.0.html'),
        ),
        // GPL-3.0 §6: users must be able to reach the corresponding source.
        ListTile(
          title: Text(l10n.sourceCode),
          subtitle: Text(Env.sourceRepositoryUrl),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => _open(Env.sourceRepositoryUrl),
        ),
        ListTile(
          title: Text(l10n.openSourceNotices),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: AppConstants.appName,
            applicationVersion: ref.read(appVersionProvider),
            applicationLegalese:
                '© 2026 CallNusa — ${AppConstants.licenseName}',
          ),
        ),
        ListTile(
          title: Text(l10n.diagnostics),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DiagnosticsScreen()),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: Text(l10n.logout),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.error,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _pickRingtone(BuildContext context, WidgetRef ref) async {
    // Bundled options; the values map to platform ringtone resources.
    const options = ['default', 'classic', 'silent'];
    final choice = await _pick(context, options, options);
    if (choice != null) {
      await ref.read(settingsProvider.notifier).setRingtone(choice);
    }
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final labels = [context.l10n.languageSystem, 'Bahasa Indonesia', 'English'];
    // 'system' rather than null, so dismissing the sheet (which returns null)
    // is distinguishable from choosing "follow the system".
    final choice = await _pick(context, labels, const ['system', 'id', 'en']);
    if (choice == null) return;
    await ref
        .read(settingsProvider.notifier)
        .setLanguage(choice == 'system' ? null : choice);
  }

  Future<String?> _pick(
    BuildContext context,
    List<String> labels,
    List<String> values,
  ) => showModalBottomSheet<String?>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < labels.length; i++)
            ListTile(
              title: Text(labels[i]),
              onTap: () => Navigator.pop(context, values[i]),
            ),
        ],
      ),
    ),
  );

  Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 1.2,
      ),
    ),
  );
}
