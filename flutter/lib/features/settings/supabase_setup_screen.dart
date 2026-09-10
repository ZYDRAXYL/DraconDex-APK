import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/i18n/app_localizations.dart';
import '../../data/services/supabase_setup_service.dart';
import '../../providers/supabase_provider.dart';

/// Settings → Cloud → Supabase project. The Flutter/PWA twin of the Electron
/// app's Setting → App Data → Supabase Project page: paste your own project's
/// URL and publishable key, press Check to see exactly which tables and
/// functions are present, then either let the app install the missing ones
/// (personal access token, used once, never stored) or copy the SQL into the
/// project's own SQL editor.
///
/// A screen rather than a dialog because the check result is a list that grows
/// — a dialog would spend most of its height scrolling on a phone.
class SupabaseSetupScreen extends ConsumerStatefulWidget {
  const SupabaseSetupScreen({super.key});

  @override
  ConsumerState<SupabaseSetupScreen> createState() => _SupabaseSetupScreenState();
}

class _SupabaseSetupScreenState extends ConsumerState<SupabaseSetupScreen> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _keyStored = false;
  SupabaseSetupResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final url = await SupabaseSetupService.loadUrl();
    final key = await SupabaseSetupService.loadKey();
    if (!mounted) return;
    setState(() {
      _urlCtrl.text = url;
      // The key field is deliberately left blank when one is stored, so saving
      // with it empty means "keep it" (SupabaseSetupService.save does exactly
      // that) and the secret never goes back onto the screen.
      _keyStored = key.isNotEmpty;
      _loading = false;
    });
  }

  String _codeMessage(AppLocalizations l10n, String code) => switch (code) {
    'no_config' => l10n.sbErrNoConfig,
    'invalid_url' => l10n.sbErrInvalidUrl,
    'bad_key' => l10n.sbErrBadKey,
    'unreachable' => l10n.sbErrUnreachable,
    'network' => l10n.sbErrNetwork,
    'needs_manual' => l10n.sbErrNeedsManual,
    'bad_access_token' => l10n.sbErrBadAccessToken,
    'forbidden' => l10n.sbErrForbidden,
    'no_project_ref' => l10n.sbErrNoProjectRef,
    'rate_limited' => l10n.sbErrRateLimited,
    'sql_error' => l10n.sbErrSqlError,
    _ => l10n.sbErrSqlError,
  };

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save({bool thenCheck = true}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final code = await SupabaseSetupService.save(_urlCtrl.text, _keyCtrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (code != null) {
      _snack(_codeMessage(l10n, code));
      return;
    }
    _keyCtrl.clear();
    _keyStored = true;
    ref.invalidate(supabaseUrlProvider);
    if (thenCheck) await _check();
  }

  Future<void> _check() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final r = await SupabaseSetupService.check();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = r.ok ? r : null;
    });
    _snack(r.ok ? (r.ready ? l10n.sbReady : l10n.sbNeedSetup) : _codeMessage(l10n, r.code!));
  }

  Future<void> _install() async {
    final l10n = AppLocalizations.of(context)!;
    if (_tokenCtrl.text.trim().isEmpty) {
      _snack(l10n.sbErrNeedsManual);
      return;
    }
    setState(() => _busy = true);
    final r = await SupabaseSetupService.install(_tokenCtrl.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = r.ok ? r : null;
    });
    if (!r.ok) {
      _snack(_codeMessage(l10n, r.code!));
      return;
    }
    _tokenCtrl.clear();
    _snack(r.ready ? l10n.sbInstalled : l10n.sbNeedSetup);
  }

  Future<void> _copySql() async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: SupabaseSetupService.setupSql));
    _snack(l10n.sbCopied);
  }

  Future<void> _openDash(String page) async {
    final l10n = AppLocalizations.of(context)!;
    final uri = SupabaseSetupService.dashboardUri(page, _urlCtrl.text.trim());
    if (uri == null) {
      _snack(l10n.sbErrNoProjectRef);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.sbClearConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.btnCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.sbClear)),
        ],
      ),
    );
    if (confirmed != true) return;
    await SupabaseSetupService.clear();
    if (!mounted) return;
    ref.invalidate(supabaseUrlProvider);
    setState(() {
      _urlCtrl.clear();
      _keyCtrl.clear();
      _keyStored = false;
      _result = null;
    });
    _snack(l10n.sbCleared);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingPageSupabase)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Hint(l10n.sbIntro),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlCtrl,
                  autocorrect: false,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.sbUrl,
                    hintText: 'https://xxxxxxxx.supabase.co',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _keyCtrl,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l10n.sbKey,
                    hintText: 'sb_publishable_...',
                    helperText: _keyStored ? l10n.sbKeyStored : null,
                    helperMaxLines: 3,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(onPressed: _busy ? null : () => _openDash('api'), child: Text(l10n.sbOpenApiSettings)),
                    OutlinedButton(onPressed: _busy ? null : _check, child: Text(l10n.sbCheck)),
                    FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.btnSave)),
                  ],
                ),
                if (_busy) const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
                const SizedBox(height: 16),
                ..._statusSection(l10n),
                if (_result?.ready != true) ..._installSection(l10n),
                const SizedBox(height: 24),
                if (_keyStored)
                  TextButton(
                    onPressed: _busy ? null : _clear,
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                    child: Text(l10n.sbClear),
                  ),
              ],
            ),
    );
  }

  List<Widget> _statusSection(AppLocalizations l10n) {
    final r = _result;
    if (r == null) return [_Hint(l10n.sbNotChecked)];
    return [
      ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(l10n.sbSchemaVersion),
        trailing: Text('${r.installedVersion} / ${SupabaseSetupService.requiredVersion}'),
      ),
      Text(l10n.sbObjects, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      for (final entry in r.objects.entries)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            entry.value ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: entry.value ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
          ),
          title: Text(entry.key, style: const TextStyle(fontFamily: 'monospace')),
        ),
      const SizedBox(height: 8),
      _Hint(r.ready ? l10n.sbReady : l10n.sbNeedSetup),
      if (r.googleProvider != null) ...[
        const SizedBox(height: 8),
        _Hint(r.googleProvider! ? l10n.sbGoogleOn : l10n.sbGoogleOff),
        if (!r.googleProvider!)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _openDash('auth'), child: Text(l10n.sbOpenAuthProviders)),
          ),
      ],
    ];
  }

  List<Widget> _installSection(AppLocalizations l10n) => [
    const Divider(height: 32),
    Text(l10n.sbAutoInstall, style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 8),
    _Hint(l10n.sbAutoInstallHint),
    const SizedBox(height: 12),
    TextField(
      controller: _tokenCtrl,
      obscureText: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: l10n.sbAccessToken,
        hintText: 'sbp_...',
        helperText: l10n.sbAccessTokenHint,
        helperMaxLines: 3,
        border: const OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        TextButton(onPressed: _busy ? null : () => _openDash('tokens'), child: Text(l10n.sbGetToken)),
        FilledButton(onPressed: _busy ? null : _install, child: Text(l10n.sbAutoInstall)),
      ],
    ),
    const Divider(height: 32),
    Text(l10n.sbManualTitle, style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 8),
    _Hint(l10n.sbManualHint),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton(onPressed: _copySql, child: Text(l10n.sbCopySql)),
        FilledButton.tonal(onPressed: () => _openDash('sql'), child: Text(l10n.sbOpenSqlEditor)),
      ],
    ),
  ];
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
