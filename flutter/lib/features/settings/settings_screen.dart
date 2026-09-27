import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/settings_provider.dart';
import '../../data/services/drive_backup_service.dart';
import '../../data/services/google_auth_service.dart';
import '../../data/services/import_export_service.dart';
import '../../providers/drive_provider.dart';
import '../../providers/supabase_provider.dart';
import '../../providers/update_provider.dart';
import '../update/update_dialog.dart';
import 'google_account_screen.dart';
import 'supabase_setup_screen.dart';
import '../../core/theme/ddx_theme.dart';
import '../../widgets/grouped_section.dart';
import 'theme_picker.dart';
import 'transfer_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.moduleSettings)),
      body: ListView(
        children: _iosGrouped(context, [
          _SectionHeader(l10n.settingsAppearance),
          const ThemePickerSection(),
          ListTile(
            title: Text(l10n.uiScaleLabel),
            subtitle: Slider(
              value: settings.uiScale,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              label: '${(settings.uiScale * 100).round()}%',
              onChanged: (v) => notifier.setUiScale(v),
            ),
          ),
          ListTile(
            title: Text(l10n.moduleNameMode),
            subtitle: Text(l10n.moduleNameModeHint),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: true, label: Text(l10n.nameModeClassic)),
                ButtonSegment(value: false, label: Text(l10n.nameModeUnique)),
              ],
              selected: {settings.classicNames},
              onSelectionChanged: (v) => notifier.setClassicNames(v.first),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.languageLabel),
          RadioGroup<String>(
            groupValue: settings.locale.languageCode,
            onChanged: (v) { if (v != null) notifier.setLocale(Locale(v)); },
            child: Column(
              children: _supportedLocales.entries.map((e) => RadioListTile<String>(
                title: Text(e.value),
                value: e.key,
              )).toList(),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsData),
          ListTile(
            leading: const Icon(Icons.upload),
            title: Text(l10n.exportDbTitle),
            subtitle: Text(l10n.exportDbSubtitle),
            onTap: () => _export(context, l10n),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: Text(l10n.importDbTitle),
            subtitle: Text(l10n.importDbSubtitle),
            onTap: () => _import(context, ref, l10n),
          ),
          ..._driveTiles(context, ref, l10n),
          // Same spot as the Google sign-in above, deliberately: both answer
          // "where does my data go besides this device?". Neither is
          // platform-gated any more — both are plain https, so they work on
          // Android and on the web/PWA build alike.
          _supabaseTile(context, ref, l10n),
          // Next to export/import and the cloud tiles because it answers the
          // same question they do — "how does this leave the device?" — and
          // differs only in needing no account and keeping nothing.
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(l10n.transferTitle),
            subtitle: Text(l10n.transferSubtitle),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TransferScreen()),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsAbout),
          ListTile(
            title: Text(l10n.appName),
            subtitle: Text('${l10n.nexusSubtitle} · v${ref.watch(appVersionProvider).valueOrNull ?? '…'}'),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: Text(l10n.checkUpdatesTitle),
            subtitle: Text(l10n.checkUpdatesSubtitle),
            onTap: () => _checkForUpdates(context, ref, l10n),
          ),
        ]),
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    ref.invalidate(updateCheckProvider);
    final result = await ref.read(updateCheckProvider.future);
    if (!context.mounted) return;
    if (result.available && result.update != null) {
      await showDialog(context: context, builder: (_) => UpdateDialog(update: result.update!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.upToDateMessage} (v${result.current})')),
      );
    }
  }

  Future<void> _export(BuildContext context, AppLocalizations l10n) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.webBackupUnsupportedMessage)));
      return;
    }
    try {
      final path = await ImportExportService.exportToShare();
      await Share.shareXFiles([XFile(path)], text: 'DraconDex backup');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.exportFailedMessage} $e')));
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.webBackupUnsupportedMessage)));
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importingMessage), duration: const Duration(seconds: 60)),
      );
    }

    try {
      final summary = await ImportExportService.importFromFile(path);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('${l10n.importCompleteMessage} $summary')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('${l10n.importFailedMessage} $e')));
      }
    }
  }

  /// Opens the "bring your own Supabase project" setup screen. The subtitle
  /// carries the configured project URL so the tile answers "is this set up?"
  /// without being tapped.
  Widget _supabaseTile(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final url = ref.watch(supabaseUrlProvider).valueOrNull ?? '';
    return ListTile(
      leading: const Icon(Icons.dns_outlined),
      title: Text(l10n.settingPageSupabase),
      subtitle: Text(url.isEmpty ? l10n.sbNotConfigured : url),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SupabaseSetupScreen()),
      ),
    );
  }

  /// Google account + Drive backup. No platform gate: the login is a plain
  /// browser OAuth flow on every target now (see google_auth_service.dart),
  /// so the web/PWA build gets it too — what differs is only that the
  /// browser has no database *file* to back up, which the note below says
  /// out loud rather than hiding the row.
  List<Widget> _driveTiles(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final config = ref.watch(googleConfigProvider).valueOrNull;
    final connection = ref.watch(googleConnectionProvider).valueOrNull ?? GoogleConnection.none;
    final configured = config?.isConfigured ?? false;

    return [
      ListTile(
        leading: const Icon(Icons.account_circle_outlined),
        title: Text(l10n.googleAccountTitle),
        subtitle: Text(configured
            ? googleConnectionLabel(l10n, connection)
            : l10n.googleAccountNotConfigured),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GoogleAccountScreen()),
          );
          ref.invalidate(googleConfigProvider);
          ref.invalidate(googleConnectionProvider);
        },
      ),
      if (connection.connected) ...[
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: Text(l10n.driveBackupNow),
          subtitle: DriveBackupService.databaseBackupSupported
              ? Text(l10n.driveBackupTitle)
              : Text(l10n.driveWebDatabaseNote),
          onTap: () => _driveBackup(context, ref, l10n),
        ),
        if (DriveBackupService.databaseBackupSupported)
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: Text(l10n.driveRestoreTitle),
            subtitle: Text(l10n.driveRestoreSubtitle),
            onTap: () => _driveRestore(context, ref, l10n),
          ),
        ListTile(
          leading: const Icon(Icons.settings_backup_restore),
          title: Text(l10n.driveRestoreSettingsTitle),
          subtitle: Text(l10n.driveRestoreSettingsSubtitle),
          onTap: () => _driveRestoreSettings(context, ref, l10n),
        ),
      ],
    ];
  }

  Future<void> _driveBackup(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.driveBackingUpMessage), duration: const Duration(seconds: 60)));
    try {
      final outcome = await DriveBackupService.backupNow();
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(
          outcome.database ? l10n.driveBackupSuccessMessage
                           : '${l10n.driveBackupSuccessMessage} ${l10n.driveWebDatabaseNote}',
        )));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(googleErrorMessage(l10n, e))));
      // An expired or revoked grant turns the account row back to
      // "not connected" instead of leaving a dead Backup button on screen.
      ref.invalidate(googleConnectionProvider);
    }
  }

  Future<void> _driveRestore(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.importingMessage), duration: const Duration(seconds: 60)));
    try {
      final summary = await DriveBackupService.restoreDatabase();
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('${l10n.importCompleteMessage} $summary')));
    } catch (e) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(googleErrorMessage(l10n, e))));
      ref.invalidate(googleConnectionProvider);
    }
  }

  /// Restoring the settings profile writes straight into SharedPreferences,
  /// which the settings notifier has already read into memory — so the
  /// provider is refreshed afterwards, otherwise the screen would keep
  /// showing the pre-restore theme until the next launch.
  Future<void> _driveRestoreSettings(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    try {
      final restored = await DriveBackupService.restoreSettings();
      if (restored) ref.invalidate(settingsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text(restored ? l10n.driveSettingsRestoredMessage : l10n.driveNoBackupMessage),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(googleErrorMessage(l10n, e))));
      ref.invalidate(googleConnectionProvider);
    }
  }

  static const _supportedLocales = {
    'en': 'English',
    'th': 'ภาษาไทย',
    'ja': '日本語',
    'ko': '한국어',
    'zh': '中文',
    'vi': 'Tiếng Việt',
    'id': 'Bahasa Indonesia',
    'es': 'Español',
    'pt': 'Português (Brasil)',
    'fr': 'Français',
    'de': 'Deutsch',
    'ru': 'Русский',
    'it': 'Italiano',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'uk': 'Українська',
    'tr': 'Türkçe',
    'qd': '🐉 Draconic',
  };
}

/// On iPhone/iPad the sections become grouped inset lists (APP
/// docs/REDESIGN.md C3): each header starts a card, the dividers between
/// sections go (the gap between cards says the same). Elsewhere, unchanged.
List<Widget> _iosGrouped(BuildContext context, List<Widget> children) {
  if (!context.isIosStyle) return children;
  final out = <Widget>[];
  String? header;
  var rows = <Widget>[];
  void flush() {
    if (rows.isNotEmpty || header != null) out.add(DdxGroupedSection(header: header, children: rows));
    rows = <Widget>[];
  }
  for (final w in children) {
    if (w is Divider) continue;
    if (w is _SectionHeader) {
      flush();
      header = w.title;
      continue;
    }
    rows.add(w);
  }
  flush();
  return [const SizedBox(height: 8), ...out];
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
