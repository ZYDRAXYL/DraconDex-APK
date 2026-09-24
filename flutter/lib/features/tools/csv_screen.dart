import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/models/recent_view_model.dart';
import '../../data/services/bundle_service.dart';
import '../../data/services/csv_import.dart';
import '../../providers/db_providers.dart';
import '../hub/dialogs/new_module_sheet.dart';
import '../page/views/classifier_views.dart';

/// CSV → Classifier (V5.md §11.10, EXE hub/csv-import.js): pick a file, see
/// every column's guessed type and change it (or skip the column), then one
/// Classifier is made at the top of the Nest.
class CsvScreen extends ConsumerStatefulWidget {
  final int nexusId;
  const CsvScreen({super.key, required this.nexusId});

  @override
  ConsumerState<CsvScreen> createState() => _CsvScreenState();
}

class _CsvScreenState extends ConsumerState<CsvScreen> {
  CsvRead? _csv;
  List<String> _types = const [];
  final _name = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pick());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final l = AppLocalizations.of(context)!;
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['csv', 'tsv', 'txt'], withData: true);
    final f = res?.files.firstOrNull;
    if (f?.bytes == null) return;
    try {
      final c = CsvImport.read(f!.bytes!);
      setState(() {
        _csv = c;
        _types = [...c.types];
        _name.text = f.name.replaceFirst(RegExp(r'\.[^.]+$'), '');
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() => _error = e.message == 'too_large' ? l.csvTooLarge : l.csvEmpty);
    }
  }

  Future<void> _create() async {
    final c = _csv;
    final name = _name.text.trim();
    if (c == null || name.isEmpty) return;
    final router = GoRouter.of(context);
    final db = await ref.read(databaseProvider.future);
    final r = await BundleService.create(db, widget.nexusId, null, CsvImport.spec(name, c, _types));
    refreshTree(ref, widget.nexusId);
    if (r.moduleIds.isNotEmpty) router.pushReplacement(RecentView.locationFor(widget.nexusId, r.moduleIds.first));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final c = _csv;
    return Scaffold(
      appBar: AppBar(title: Text(l.csvImportTitle), actions: [
        IconButton(tooltip: l.csvPick, icon: const Icon(Icons.file_open_outlined), onPressed: _pick),
      ]),
      floatingActionButton: c == null ? null : FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.check), label: Text(l.csvCreate)),
      body: c == null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
                Padding(padding: const EdgeInsets.all(16), child: Text(l.csvHint, textAlign: TextAlign.center)),
                FilledButton.icon(onPressed: _pick, icon: const Icon(Icons.file_open_outlined), label: Text(l.csvPick)),
              ]),
            )
          : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
              TextField(controller: _name, decoration: InputDecoration(labelText: '${l.labelName} *')),
              const SizedBox(height: 8),
              Text('${c.rows.length} · ${c.encoding}${c.truncated ? ' · ${l.csvTruncated}' : ''}', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              for (var i = 0; i < c.header.length; i++)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.header[i]),
                  subtitle: Text(
                    c.rows.take(3).map((r) => r[i]).where((v) => v.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: i == 0
                      ? Text(l.csvNameColumn, style: theme.textTheme.labelMedium)
                      : DropdownButton<String>(
                          value: _types[i],
                          items: [
                            for (final t in CsvImport.types)
                              DropdownMenuItem(value: t, child: Text(t == 'skip' ? l.csvSkip : clsTypeLabel(l, t))),
                          ],
                          onChanged: (v) => setState(() => _types[i] = v ?? _types[i]),
                        ),
                ),
            ]),
    );
  }
}
