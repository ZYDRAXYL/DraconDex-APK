import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/module_model.dart';
import '../../../data/services/bundle_service.dart';
import '../../../providers/db_providers.dart';

class NexusDialog extends ConsumerStatefulWidget {
  final NexusModel? existing;
  const NexusDialog({super.key, this.existing});

  @override
  ConsumerState<NexusDialog> createState() => _NexusDialogState();
}

class _NexusDialogState extends ConsumerState<NexusDialog> {
  late final TextEditingController _name;
  late final TextEditingController _memo;

  /// What a new Nexus starts with: '' empty, 'guide', or a bundle's id.
  String _start = '';
  Future<List<Map<String, dynamic>>>? _bundles;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _memo = TextEditingController(text: widget.existing?.memo ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.existing == null ? l10n.newNexusTitle : l10n.renameNexusTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: _name, autofocus: true, decoration: InputDecoration(labelText: '${l10n.labelName} *')),
          const SizedBox(height: 12),
          TextField(controller: _memo, decoration: InputDecoration(labelText: l10n.labelMemo), maxLines: 2),
          if (widget.existing == null) ...[
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _bundles ??= BundleService.loadBundles(Localizations.localeOf(context).languageCode),
              builder: (context, snap) => DropdownButtonFormField<String>(
                initialValue: _start,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.nexusStartWith),
                items: [
                  DropdownMenuItem(value: '', child: Text(l10n.nexusStartEmpty)),
                  DropdownMenuItem(value: 'guide', child: Text(l10n.guideTitle)),
                  for (final b in snap.data ?? const <Map<String, dynamic>>[])
                    DropdownMenuItem(value: '${b['id']}', child: Text('${b['name']}')),
                ],
                onChanged: (v) => setState(() => _start = v ?? ''),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.btnCancel)),
        FilledButton(onPressed: _save, child: Text(l10n.btnSave)),
      ],
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final memo = _memo.text.trim().isEmpty ? null : _memo.text.trim();
    final locale = Localizations.localeOf(context).languageCode;
    // Was: the DAO's own AsyncValue.error branch was the only thing caught
    // here, so an exception thrown by createNexus/updateNexus itself (e.g. a
    // DB write failure) propagated straight out of this async callback —
    // Flutter reports that to the zone error handler, not to this dialog, so
    // it never reached Navigator.pop() but also never told the user anything
    // went wrong. The dialog just... stayed there, or the tap looked like it
    // did nothing. Wrapping the whole save in try/catch means every failure
    // path shows saveFailedMessage and only a real success closes the dialog.
    try {
      await ref.read(moduleDaoProvider).when(
        data: (d) async {
          if (widget.existing == null) {
            final id = await d.createNexus(name: name, memo: memo);
            if (_start.isNotEmpty) {
              Map<String, dynamic> spec;
              if (_start == 'guide') {
                spec = await BundleService.loadGuide(locale);
              } else {
                final b = (await BundleService.loadBundles(locale)).firstWhere((b) => b['id'] == _start);
                spec = {...(b['spec'] as Map<String, dynamic>), 'name': b['name'], 'icon': b['icon']};
              }
              await BundleService.create(d.db, id, null, spec);
            }
          } else {
            await d.updateNexus(widget.existing!.id, name: name, memo: memo, colorId: widget.existing!.colorId);
          }
        },
        loading: () => throw StateError('database not ready'),
        error: (e, s) => throw e,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.saveFailedMessage} $e')));
    }
  }
}
