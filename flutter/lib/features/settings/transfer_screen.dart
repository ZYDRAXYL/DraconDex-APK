import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/models/module_model.dart';
import '../../data/services/ddx_transfer_service.dart';
import '../../data/dao/module_dao.dart';
import '../../data/services/vault_snapshot_service.dart';
import '../../providers/db_providers.dart';
import '../../providers/module_provider.dart';

/// Settings → Data → DDX Transfer. The Flutter twin of the Electron app's
/// Setting → App data → Transfer page.
///
/// Sending serializes a Nexus, seals it on this device and uploads only
/// ciphertext; receiving proves a code and a PIN, shows WHAT is arriving, and
/// only then downloads it. The transfer key is made here, lives in
/// [TransferVerifyResult]/[TransferSendResult], and is never written to a
/// widget, a log, or shared_preferences.
///
/// There is no camera scanner here on purpose. A QR is for the OTHER device to
/// read — the phone's own camera app opens the link, and a link pasted into
/// the Receive tab carries the key in its fragment, which gets the same
/// end-to-end result without this app asking for a camera permission it would
/// need on every install for a screen most people open once.
class TransferScreen extends ConsumerStatefulWidget {
  const TransferScreen({super.key});

  @override
  ConsumerState<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends ConsumerState<TransferScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _service = DdxTransferService();

  // Send
  int? _sendNexusId;
  bool _allowTypedCode = true;
  bool _sending = false;
  TransferSendResult? _sent;
  String? _sendStatusKey;

  // Receive
  final _codeCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  bool _busy = false;
  TransferVerifyResult? _verified;

  // Separate per tab: one shared field meant a failed Verify still showed its
  // message over on the Send tab after switching.
  String? _sendError;
  String? _recvError;

  @override
  void dispose() {
    _tabs.dispose();
    _codeCtrl.dispose();
    _pinCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  /// Service error codes never reach the user raw — this is the only place
  /// they turn into words.
  String _message(AppLocalizations l10n, String code) {
    switch (code) {
      case 'network':      return l10n.transferErrNetwork;
      case 'bad_code':     return l10n.transferErrBadCode;
      case 'locked':       return l10n.transferErrLocked;
      case 'expired':      return l10n.transferErrExpired;
      case 'gone':         return l10n.transferErrGone;
      case 'not_ready':    return l10n.transferErrNotReady;
      case 'too_large':    return l10n.transferErrTooLarge;
      case 'bad_token':    return l10n.transferErrBadToken;
      case 'bad_key':      return l10n.transferErrBadKey;
      case 'qr_only':      return l10n.transferErrQrOnly;
      case 'bad_payload':  return l10n.transferErrBadPayload;
      default:             return l10n.transferErrServer;
    }
  }

  static String _formatBytes(int n) {
    if (n < 1024) return '$n B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transferTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.transferTabSend),
            Tab(text: l10n.transferTabReceive),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_sendTab(l10n), _receiveTab(l10n)],
      ),
    );
  }

  // -------------------------------------------------------------------
  // Send
  // -------------------------------------------------------------------

  Widget _sendTab(AppLocalizations l10n) {
    final sent = _sent;
    if (sent != null) return _sentView(l10n, sent);

    final nexusesAsync = ref.watch(nexusesProvider);
    return nexusesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text('$e', textAlign: TextAlign.center),
      )),
      data: (nexuses) {
        if (nexuses.isEmpty) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.transferPickNexus, textAlign: TextAlign.center),
          ));
        }
        final selected = _sendNexusId ?? nexuses.first.id;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.transferSubtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: selected,
              decoration: InputDecoration(
                labelText: l10n.transferNexusLabel,
                border: const OutlineInputBorder(),
              ),
              items: nexuses
                  .map((NexusModel n) => DropdownMenuItem<int>(value: n.id, child: Text(n.name)))
                  .toList(),
              onChanged: (v) => setState(() => _sendNexusId = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _allowTypedCode,
              onChanged: (v) => setState(() => _allowTypedCode = v),
              title: Text(l10n.transferAllowTyped),
              subtitle: Text(l10n.transferAllowTypedHint),
            ),
            const SizedBox(height: 8),
            if (_sendError != null) _errorBox(_sendError!),
            FilledButton.icon(
              onPressed: _sending ? null : () => _doSend(l10n, selected, nexuses),
              icon: _sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share),
              label: Text(_sending ? l10n.transferSending : l10n.transferCreate),
            ),
          ],
        );
      },
    );
  }

  Future<void> _doSend(AppLocalizations l10n, int nexusId, List<NexusModel> nexuses) async {
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final db = await ref.read(databaseProvider.future);
      final snapshot = await VaultSnapshotService.serializeVault(db, nexusId);
      if (snapshot == null) throw const DdxTransferException('gone');

      final name = nexuses.firstWhere((n) => n.id == nexusId).name;
      final sent = await _service.send(
        snapshot: snapshot,
        name: name,
        allowTypedCode: _allowTypedCode,
      );
      if (!mounted) return;
      setState(() {
        _sent = sent;
        _sending = false;
      });
      _pollStatus(sent);
    } on DdxTransferException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendError = _message(l10n, e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendError = _message(l10n, 'server_error');
      });
    }
  }

  /// Polls until the other device takes it. `gone` means received: the service
  /// purges a transfer on /api/complete, so the sender's own status call stops
  /// finding it.
  Future<void> _pollStatus(TransferSendResult sent) async {
    while (mounted && _sent?.transferId == sent.transferId) {
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!mounted || _sent?.transferId != sent.transferId) return;
      try {
        final st = await _service.status(sent.transferId, sent.uploadToken);
        if (!mounted) return;
        if (st.status == 'gone') {
          setState(() => _sendStatusKey = 'done');
          return;
        }
        if (st.status == 'expired') {
          setState(() => _sendStatusKey = 'expired');
          return;
        }
        if (st.claimed) setState(() => _sendStatusKey = 'claimed');
      } on DdxTransferException catch (e) {
        // The transfer being gone is the success case, not a failure.
        if (e.code == 'gone') {
          if (mounted) setState(() => _sendStatusKey = 'done');
          return;
        }
        // Anything else is very likely a blip; keep waiting rather than
        // interrupting someone who is reading a code aloud.
      }
    }
  }

  Widget _sentView(AppLocalizations l10n, TransferSendResult sent) {
    final statusText = switch (_sendStatusKey) {
      'done' => l10n.transferDone,
      'expired' => l10n.transferExpiredNotice,
      'claimed' => l10n.transferClaimed,
      _ => l10n.transferWaiting,
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(child: Column(children: [
          Text(l10n.transferCode, style: Theme.of(context).textTheme.labelSmall),
          SelectableText(
            sent.codeDisplay,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 30, fontWeight: FontWeight.w600, letterSpacing: 3),
          ),
          if (sent.allowTypedCode) ...[
            const SizedBox(height: 12),
            Text(l10n.transferPin, style: Theme.of(context).textTheme.labelSmall),
            SelectableText(
              sent.pinDisplay,
              style: TextStyle(
                fontFamily: 'monospace', fontSize: 24, fontWeight: FontWeight.w600,
                letterSpacing: 3, color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // A white plate under the QR is not decoration: the quiet zone is
          // part of the spec, and a dark-themed surface without it does not
          // scan.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: QrImageView(
              data: sent.link,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
          ),
        ])),
        const SizedBox(height: 20),
        _noteBox(sent.allowTypedCode ? l10n.transferModeTyped : l10n.transferModeQr),
        _noteBox(l10n.transferExpiry),
        _noteBox(statusText),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: sent.link));
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.transferCopied)));
          },
          icon: const Icon(Icons.link),
          label: Text(l10n.transferCopyLink),
        ),
        TextButton(
          onPressed: () async {
            final finished = _sendStatusKey == 'done' || _sendStatusKey == 'expired';
            setState(() {
              _sent = null;
              _sendStatusKey = null;
            });
            // Cancelling on the way out is the point: a code left alive after
            // the user walks away is their vault sitting on the service for
            // the rest of its thirty minutes.
            if (!finished) {
              try {
                await _service.cancel(sent.transferId, sent.uploadToken);
              } catch (_) {/* the sweeper is the backstop */}
            }
          },
          child: Text(l10n.transferCancel),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Receive
  // -------------------------------------------------------------------

  Widget _receiveTab(AppLocalizations l10n) {
    final verified = _verified;
    if (verified != null) return _foundView(l10n, verified);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: l10n.transferCode,
            hintText: 'ABCD-EFGH',
            border: const OutlineInputBorder(),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 18, letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pinCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.transferPin,
            hintText: '482-719',
            border: const OutlineInputBorder(),
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 18, letterSpacing: 2),
        ),
        const SizedBox(height: 20),
        // The end-to-end path without a camera: a pasted link carries the key
        // in its fragment, so the service never held one.
        TextField(
          controller: _linkCtrl,
          decoration: InputDecoration(
            labelText: l10n.transferPasteLink,
            helperText: l10n.transferPasteLinkHint,
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) {
            final parsed = DdxTransferService.parseLink(v);
            if (parsed == null) return;
            // Filling both fields is what makes a pasted link a one-tap
            // receive rather than a second thing to copy across.
            _codeCtrl.text = parsed.code.length == 8
                ? '${parsed.code.substring(0, 4)}-${parsed.code.substring(4)}'
                : parsed.code;
            if (parsed.pin.isNotEmpty) _pinCtrl.text = parsed.pin;
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        if (_recvError != null) _errorBox(_recvError!),
        FilledButton.icon(
          onPressed: _busy ? null : () => _doVerify(l10n),
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          label: Text(l10n.transferVerify),
        ),
      ],
    );
  }

  Future<void> _doVerify(AppLocalizations l10n) async {
    setState(() {
      _busy = true;
      _recvError = null;
    });
    try {
      final link = DdxTransferService.parseLink(_linkCtrl.text);
      final result = await _service.verify(
        code: _codeCtrl.text,
        pin: _pinCtrl.text,
        linkKey: link?.key,
      );
      if (!mounted) return;
      setState(() {
        _verified = result;
        _busy = false;
      });
    } on DdxTransferException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _recvError = _message(l10n, e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _recvError = _message(l10n, 'server_error');
      });
    }
  }

  Widget _foundView(AppLocalizations l10n, TransferVerifyResult v) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.transferFound, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _row(l10n.transferProject, v.name),
        _row(l10n.transferSize, _formatBytes(v.sizeBytes)),
        _row(l10n.transferCreated,
            DateTime.fromMillisecondsSinceEpoch(v.createdAt).toLocal().toString().split('.').first),
        _row(l10n.transferSource, v.source ?? '—'),
        const SizedBox(height: 12),
        _noteBox(l10n.transferReceiveAsNew),
        if (_recvError != null) _errorBox(_recvError!),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _busy ? null : () => _doReceive(l10n, v),
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download),
          label: Text(l10n.transferReceiveAction),
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _verified = null),
          child: Text(l10n.transferCancel),
        ),
      ],
    );
  }

  /// Always into a NEW Nexus. applySnapshot is wipe-and-rebuild, so pointing
  /// it at an existing vault destroys that vault's contents — and a transfer
  /// arriving from someone else is never a thing to aim at the vault you are
  /// working in.
  Future<void> _doReceive(AppLocalizations l10n, TransferVerifyResult v) async {
    setState(() {
      _busy = true;
      _recvError = null;
    });
    try {
      final payload = await _service.receive(v);
      final db = await ref.read(databaseProvider.future);
      // moduleDaoProvider is a Provider<AsyncValue<ModuleDao>>, not a
      // FutureProvider — it has no `.future`. The database is already awaited
      // here, so build the DAO from it directly.
      final dao = ModuleDao(db);

      // nexus.name is UNIQUE, so make room rather than failing the user at the
      // last step of a transfer.
      final existing = (await dao.getNexuses()).map((n) => n.name).toSet();
      var name = v.name.isEmpty ? 'Nexus' : v.name;
      if (existing.contains(name)) {
        var i = 2;
        while (existing.contains('$name ($i)')) {
          i++;
        }
        name = '$name ($i)';
      }

      final newId = await dao.createNexus(name: name);
      final applied = await VaultSnapshotService.applySnapshot(db, newId, payload);
      if (!applied.ok) throw DdxTransferException(applied.code ?? 'bad_payload');

      ref.invalidate(nexusesProvider);
      if (!mounted) return;
      setState(() {
        _verified = null;
        _busy = false;
        _codeCtrl.clear();
        _pinCtrl.clear();
        _linkCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.transferReceived)));
    } on DdxTransferException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _recvError = _message(l10n, e.code);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _recvError = _message(l10n, 'server_error');
      });
    }
  }

  // -------------------------------------------------------------------

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
            Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      );

  Widget _noteBox(String text) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );

  Widget _errorBox(String text) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
      );
}
