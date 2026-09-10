import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/services/drive_backup_service.dart';
import '../../data/services/google_auth_service.dart';
import '../../providers/drive_provider.dart';

/// Settings → Google account. The Flutter/PWA twin of the Electron app's
/// Setting → User → Account page: enter the OAuth client from your own
/// Google Cloud project once, then connect and disconnect the account that
/// Google Drive backup runs as.
///
/// A screen rather than a dialog for the same reason SupabaseSetupScreen is
/// one — the setup instructions plus two fields plus the connection state do
/// not fit a phone-sized dialog without it becoming a scroll box.
class GoogleAccountScreen extends ConsumerStatefulWidget {
  const GoogleAccountScreen({super.key});

  @override
  ConsumerState<GoogleAccountScreen> createState() => _GoogleAccountScreenState();
}

class _GoogleAccountScreenState extends ConsumerState<GoogleAccountScreen> {
  final _clientIdCtrl = TextEditingController();
  final _clientSecretCtrl = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  bool _secretStored = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _clientSecretCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await GoogleAuthService.loadConfig();
    if (!mounted) return;
    setState(() {
      _clientIdCtrl.text = config.clientId;
      // The secret field stays blank when one is stored, so saving with it
      // empty means "keep it" and the secret never goes back onto the screen
      // — same rule as the Supabase key field next door.
      _secretStored = config.clientSecret.isNotEmpty;
      _loading = false;
    });
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await GoogleAuthService.saveConfig(
      clientId: _clientIdCtrl.text,
      clientSecret: _clientSecretCtrl.text,
    );
    if (!mounted) return;
    final enteredSecret = _clientSecretCtrl.text.trim().isNotEmpty;
    _clientSecretCtrl.clear();
    setState(() {
      _busy = false;
      _secretStored = _secretStored || enteredSecret;
    });
    ref.invalidate(googleConfigProvider);
    ref.invalidate(googleConnectionProvider);
  }

  Future<void> _connect() async {
    final l10n = AppLocalizations.of(context)!;
    // Before the first await, while the browser still counts this as the
    // user's click — otherwise the web build's consent popup is blocked.
    GoogleAuthService.beginInteractive();
    // Saved first so a client id typed but not yet saved is the one used —
    // otherwise pressing Connect right after typing would fail with
    // no_config for a reason nothing on screen explains.
    await GoogleAuthService.saveConfig(
      clientId: _clientIdCtrl.text,
      clientSecret: _clientSecretCtrl.text,
    );
    setState(() => _busy = true);
    try {
      final email = await GoogleAuthService.connect();
      if (!mounted) return;
      _snack(googleConnectionLabel(l10n, GoogleConnection(email: email, connected: true)));
    } catch (e) {
      if (mounted) _snack(googleErrorMessage(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(googleConnectionProvider);
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    await GoogleAuthService.disconnect();
    if (mounted) setState(() => _busy = false);
    ref.invalidate(googleConnectionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final connection = ref.watch(googleConnectionProvider).valueOrNull ?? GoogleConnection.none;
    final redirectUri = GoogleAuthService.redirectUriHint;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.googleAccountSetupTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  GoogleAuthService.needsClientSecret
                      ? l10n.googleClientTypeHintNative
                      : l10n.googleClientTypeHintWeb,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                // Web only: Google matches the redirect URI character for
                // character, so it is shown rather than described.
                if (redirectUri != null) ...[
                  _RedirectUriBox(uri: redirectUri, l10n: l10n, onCopied: () => _snack(l10n.sbCopied)),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _clientIdCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.googleClientIdLabel,
                    border: const OutlineInputBorder(),
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                ),
                if (GoogleAuthService.needsClientSecret) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clientSecretCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.googleClientSecretLabel,
                      helperText: _secretStored ? l10n.googleClientSecretKept : null,
                      helperMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _busy ? null : _save,
                      child: Text(l10n.btnSave),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : (connection.connected ? _disconnect : _connect),
                      icon: Icon(connection.connected ? Icons.logout : Icons.cloud_outlined),
                      label: Text(connection.connected ? l10n.driveDisconnect : l10n.driveConnect),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(l10n.googleAccountTitle),
                  subtitle: Text(googleConnectionLabel(l10n, connection)),
                ),
                if (_busy) const LinearProgressIndicator(),
              ],
            ),
    );
  }
}

/// The one-line account state, shared with the Settings list so both places
/// tell the same story about the same connection.
String googleConnectionLabel(AppLocalizations l10n, GoogleConnection connection) {
  if (connection.connected) {
    final email = connection.email ?? '';
    // driveConnectedAs is the "Connected:" label; with no email to put after
    // it (Google's userinfo call can fail without the grant failing) the
    // label alone still says the true thing.
    return email.isEmpty ? l10n.driveConnectedAs : '${l10n.driveConnectedAs} $email';
  }
  if (connection.expired) return l10n.googleSessionExpired;
  return l10n.driveNotConnected;
}

/// Maps the login's and the backup's failure codes to localized text, so a
/// raw exception string never reaches a snackbar. Anything unrecognized
/// falls back to the generic connect-failed line rather than being hidden.
String googleErrorMessage(AppLocalizations l10n, Object error) {
  final code = switch (error) {
    GoogleAuthException e => e.code,
    DriveBackupException e => e.code,
    _ => '',
  };
  return switch (code) {
    'no_config' => l10n.googleErrNoConfig,
    'cancelled' => l10n.googleErrCancelled,
    'login_timeout' => l10n.googleErrTimeout,
    'state_mismatch' => l10n.googleErrVerify,
    'network' => l10n.googleErrNetwork,
    'auth' => l10n.googleErrAuth,
    'popup_blocked' => l10n.googleErrPopupBlocked,
    'not_connected' => l10n.googleErrNotConnected,
    'no_backup' => l10n.driveNoBackupMessage,
    'unsupported' => l10n.webBackupUnsupportedMessage,
    'bad_backup' || 'drive' || 'drive_full' => l10n.driveBackupFailedMessage,
    _ => '${l10n.driveConnectFailedMessage} $error',
  };
}

class _RedirectUriBox extends StatelessWidget {
  final String uri;
  final AppLocalizations l10n;
  final VoidCallback onCopied;

  const _RedirectUriBox({required this.uri, required this.l10n, required this.onCopied});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.googleRedirectUriLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SelectableText(uri, style: theme.textTheme.bodySmall),
            ),
            IconButton(
              tooltip: l10n.sbCopied,
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: uri));
                onCopied();
              },
            ),
          ],
        ),
        Text(l10n.googleRedirectUriHint, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
