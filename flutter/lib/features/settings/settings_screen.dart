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
import '../../core/theme/tokens.g.dart';
import '../../widgets/ddx_list.dart';
import 'theme_picker.dart';
import 'transfer_screen.dart';
import '../../widgets/ddx_glass.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: DdxGlassBar(child: AppBar(title: Text(l10n.moduleSettings))),
      // One DdxListSection per topic (UX-LAYOUT §12): on iPhone/iPad each is
      // a grouped inset card (C3), elsewhere a header over plain rows.
      body: ListView(
        children: [
          if (context.isIosStyle) const SizedBox(height: DdxSpace.sp3),
          DdxListSection(title: l10n.settingsAppearance, collapsible: false, children: [
            const ThemePickerSection(),
            // The UI style (Procress 23): how the chrome is drawn, over
            // whichever theme is picked above — a style, not a palette.
            DdxListTile(title: l10n.uiStyleLabel),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<UiStyle>(
                key: const ValueKey('ui-style'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: UiStyle.standard, label: Text(l10n.uiStyleStandard)),
                  ButtonSegment(value: UiStyle.glass, icon: const Icon(Icons.blur_on), label: Text(l10n.uiStyleGlass)),
                ],
                selected: {settings.uiStyle},
                onSelectionChanged: (v) => notifier.setUiStyle(v.first),
              ),
            ),
            if (settings.glass && settings.glassBlur == GlassBlur.off)
              // a sentence the reader must see whole, so not a one-line row
              ListTile(
                leading: const Icon(Icons.blur_off),
                title: Text(l10n.glassBlurOff),
                trailing: TextButton(
                  onPressed: () => notifier.setGlassBlur(GlassBlur.unmeasured),
                  child: Text(l10n.glassBlurRetry),
                ),
              ),
            // Always shown: it also makes the iPhone's translucent tab bar
            // and action sheets solid, Glass or not.
            SwitchListTile(
              key: const ValueKey('reduce-transparency'),
              title: Text(l10n.reduceTransparency),
              subtitle: Text(l10n.reduceTransparencyHint),
              value: settings.reduceTransparency,
              onChanged: notifier.setReduceTransparency,
            ),
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
            DdxListTile(title: l10n.moduleNameMode, meta: l10n.moduleNameModeHint, metaMaxLines: 2),
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
          ]),
          RadioGroup<String>(
            groupValue: settings.locale.languageCode,
            onChanged: (v) { if (v != null) notifier.setLocale(Locale(v)); },
            child: DdxListSection(title: l10n.languageLabel, collapsible: false, children: [
              for (final e in _supportedLocales.entries)
                DdxListTile(
                  leading: Radio<String>(
                    value: e.key,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  title: e.value,
                  selected: settings.locale.languageCode == e.key,
                  onTap: () => notifier.setLocale(Locale(e.key)),
                ),
            ]),
          ),
          DdxListSection(title: l10n.settingsData, collapsible: false, children: [
            DdxListTile(
              icon: Icons.upload,
              title: l10n.exportDbTitle,
              meta: l10n.exportDbSubtitle,
              onTap: () => _export(context, l10n),
            ),
            DdxListTile(
              icon: Icons.download,
              title: l10n.importDbTitle,
              meta: l10n.importDbSubtitle,
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
            DdxListTile(
              icon: Icons.swap_horiz,
              title: l10n.transferTitle,
              meta: l10n.transferSubtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TransferScreen()),
              ),
            ),
          ]),
          DdxListSection(title: l10n.settingsAbout, collapsible: false, children: [
            DdxListTile(
              title: l10n.appName,
              meta: '${l10n.nexusSubtitle} · v${ref.watch(appVersionProvider).valueOrNull ?? '…'}',
            ),
            DdxListTile(
              icon: Icons.system_update_alt,
              title: l10n.checkUpdatesTitle,
              meta: l10n.checkUpdatesSubtitle,
              onTap: () => _checkForUpdates(context, ref, l10n),
            ),
          ]),
          const _CreditLine(),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    ref.invalidate(updateCheckProvider);
    final result = await ref.read(updateCheckProvider.future);
    if (!context.mounted) return;
    if (result.available && result.update != null) {
      await showDdxDialog(context: context, builder: (_) => UpdateDialog(update: result.update!));
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
    return DdxListTile(
      icon: Icons.dns_outlined,
      title: l10n.settingPageSupabase,
      meta: url.isEmpty ? l10n.sbNotConfigured : url,
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
      DdxListTile(
        icon: Icons.account_circle_outlined,
        title: l10n.googleAccountTitle,
        meta: configured ? googleConnectionLabel(l10n, connection) : l10n.googleAccountNotConfigured,
        trailing: const [Icon(Icons.chevron_right, size: DdxSize.iconMd)],
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GoogleAccountScreen()),
          );
          ref.invalidate(googleConfigProvider);
          ref.invalidate(googleConnectionProvider);
        },
      ),
      if (connection.connected) ...[
        DdxListTile(
          icon: Icons.backup_outlined,
          title: l10n.driveBackupNow,
          // the browser's note is a sentence the reader must see whole
          meta: DriveBackupService.databaseBackupSupported ? l10n.driveBackupTitle : l10n.driveWebDatabaseNote,
          metaMaxLines: DriveBackupService.databaseBackupSupported ? 1 : 3,
          onTap: () => _driveBackup(context, ref, l10n),
        ),
        if (DriveBackupService.databaseBackupSupported)
          DdxListTile(
            icon: Icons.restore_outlined,
            title: l10n.driveRestoreTitle,
            meta: l10n.driveRestoreSubtitle,
            onTap: () => _driveRestore(context, ref, l10n),
          ),
        DdxListTile(
          icon: Icons.settings_backup_restore,
          title: l10n.driveRestoreSettingsTitle,
          meta: l10n.driveRestoreSettingsSubtitle,
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

/// The credit line at the very bottom of Settings — quiet, theme-coloured,
/// only seen by someone who scrolls all the way down.
class _CreditLine extends StatelessWidget {
  const _CreditLine();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Text(
        'Created by LDKTC',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
