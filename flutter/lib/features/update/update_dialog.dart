import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/platform/platform_check.dart';
import '../../data/services/apk_installer.dart' as apk_installer;
import '../../data/services/update_service.dart';

/// Shown once per new release. On Android, "Install now" downloads the
/// release APK and hands it straight to the system package installer — this
/// app has no store to defer to, so that IS the update path (see
/// apk_installer.dart's downloadApk/installApk). Everywhere else, and as a fallback
/// when the release has no APK asset or the install attempt fails, "Download"
/// just opens the GitHub release page in a browser. "Remind me later" always
/// just dismisses this version (a newer release still prompts again). See
/// docs/UPDATE.md.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo update;
  const UpdateDialog({super.key, required this.update});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum _Stage { idle, downloading, verifying, installing, error }

class _UpdateDialogState extends State<UpdateDialog> {
  _Stage _stage = _Stage.idle;
  double _progress = 0;
  String? _error;

  bool get _busy => _stage == _Stage.downloading || _stage == _Stage.verifying || _stage == _Stage.installing;

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    final canInstallDirectly = isAndroidPlatform && UpdateService.apkAsset(update) != null;

    return AlertDialog(
      title: Text('Update available: v${update.version}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(update.notes.trim().isEmpty ? 'No release notes.' : update.notes.trim()),
              if (_stage == _Stage.downloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress > 0 ? _progress : null),
                const SizedBox(height: 4),
                Text(_progress > 0 ? 'Downloading… ${(_progress * 100).round()}%' : 'Downloading…'),
              ] else if (_stage == _Stage.verifying) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 4),
                const Text('Verifying download…'),
              ] else if (_stage == _Stage.installing) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 4),
                const Text('Opening installer…'),
              ] else if (_stage == _Stage.error) ...[
                const SizedBox(height: 12),
                Text(_error ?? 'Something went wrong.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () async {
                  await UpdateService.dismiss(update.version);
                  if (context.mounted) Navigator.of(context).pop();
                },
          child: const Text('Remind me later'),
        ),
        if (canInstallDirectly || _stage == _Stage.error)
          TextButton(
            onPressed: _busy ? null : () => _openDownload(update.url),
            child: const Text('Open release page'),
          ),
        FilledButton(
          onPressed: _busy ? null : () => canInstallDirectly ? _installNow(update) : _openDownload(update.url, popAfter: true),
          child: Text(canInstallDirectly ? 'Install now' : 'Download'),
        ),
      ],
    );
  }

  Future<void> _installNow(UpdateInfo update) async {
    final asset = UpdateService.apkAsset(update);
    if (asset == null) return;
    setState(() {
      _stage = _Stage.downloading;
      _progress = 0;
      _error = null;
    });
    try {
      // Fetched before the APK so a corrupt download can be named as such
      // instead of reaching Android's package installer, which reports every
      // unparseable APK with the same generic "invalid package" message.
      // Null (no checksums asset on this release, or the fetch failed) means
      // "cannot verify" — the length check inside downloadApk still applies.
      final expected = await UpdateService.fetchExpectedSha256(update, asset);
      if (!mounted) return;
      final file = await apk_installer.downloadApk(
        asset,
        expectedSha256: expected,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onVerifying: () {
          if (mounted) setState(() => _stage = _Stage.verifying);
        },
      );
      if (!mounted) return;
      setState(() => _stage = _Stage.installing);
      final result = await apk_installer.installApk(file);
      if (!mounted) return;
      if (result.type == ResultType.done) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _stage = _Stage.error;
        _error = switch (result.type) {
          ResultType.permissionDenied =>
            'Android blocked the install. Allow "Install unknown apps" for DraconDex in Settings, then try again.',
          ResultType.fileNotFound => 'The downloaded file could not be found.',
          ResultType.noAppToOpen => 'No installer app is available on this device.',
          _ => result.message.isNotEmpty ? result.message : 'The install could not be started.',
        };
      });
    } on apk_installer.ApkIntegrityException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = 'Download failed: $e';
      });
    }
  }

  // The URL travels through this widget rather than being trusted outright —
  // re-check the prefix before handing it to the OS, the same defense in
  // depth as electron's openUpdateDownload().
  Future<void> _openDownload(String url, {bool popAfter = false}) async {
    final ok = url == UpdateService.releaseUrlPrefix || url.startsWith('${UpdateService.releaseUrlPrefix}/');
    if (ok) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
    if (popAfter && context.mounted) Navigator.of(context).pop();
  }
}
