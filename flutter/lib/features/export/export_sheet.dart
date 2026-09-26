import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/entity/entity_kinds.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../data/models/module_model.dart';
import '../../data/services/export/export_service.dart';
import '../../providers/db_providers.dart';

/// "Export…" — every way out of the app for this page, as cards (Procress 14,
/// APP docs/EXPORT-DECOR.md E8; the desktop's hub/export.js). A card that
/// cannot do anything for this kind is dimmed with the reason, not hidden.
/// The file goes out through the share sheet, the same way on Android and
/// in the browser; a PDF can go to the printer instead.
Future<void> showExportSheet(BuildContext context, WidgetRef ref, ModuleModel module, {String? itemKey, String? itemName}) async {
  final db = await ref.read(databaseProvider.future);
  final prefs = await ExportPrefs.load(db, module.id);
  final name = itemName ?? (itemKey == null ? null : await EntityKinds.nameOf(db, itemKey));
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ExportSheet(module: module, itemKey: itemKey, itemName: name, initial: prefs),
  );
}

class _Card {
  final ExportFormat f;
  final IconData icon;
  const _Card(this.f, this.icon);
}

const _cards = [
  _Card(ExportFormat.pdf, Icons.picture_as_pdf_outlined),
  _Card(ExportFormat.docx, Icons.description_outlined),
  _Card(ExportFormat.epub, Icons.menu_book_outlined),
  _Card(ExportFormat.xlsx, Icons.table_chart_outlined),
  _Card(ExportFormat.csv, Icons.list_alt),
  _Card(ExportFormat.html, Icons.public),
  _Card(ExportFormat.md, Icons.edit_note),
  _Card(ExportFormat.mddx, Icons.ios_share),
];

class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key, required this.module, this.itemKey, this.itemName, required this.initial});

  final ModuleModel module;
  final String? itemKey;
  final String? itemName;
  final ExportPrefs initial;

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  late ExportPrefs _p;
  bool _busy = false;

  String get _kind => widget.module.kind.id;

  @override
  void initState() {
    super.initState();
    _p = widget.initial;
    if (widget.itemKey != null) _p = _p.copyWith(scope: 'page');
    final cur = ExportFormat.values.where((f) => f.name == _p.fmt).firstOrNull;
    if (cur == null || exportBlocked(cur, _kind) != null) {
      _p = _p.copyWith(fmt: _cards.firstWhere((c) => exportBlocked(c.f, _kind) == null).f.name);
    }
  }

  ExportFormat get _fmt => ExportFormat.values.firstWhere((f) => f.name == _p.fmt);

  String _title(AppLocalizations l, ExportFormat f) => switch (f) {
    ExportFormat.pdf => l.exportPdf,
    ExportFormat.docx => l.exportDocx,
    ExportFormat.epub => l.exportEpub,
    ExportFormat.xlsx => l.exportXlsx,
    ExportFormat.csv => l.exportCsv,
    ExportFormat.html => l.htmlExport,
    ExportFormat.md => l.exportMarkdown,
    ExportFormat.mddx => l.mddxExport,
  };

  String _desc(AppLocalizations l, ExportFormat f) => switch (f) {
    ExportFormat.pdf => l.exportPdfD,
    ExportFormat.docx => l.exportDocxD,
    ExportFormat.epub => l.exportEpubD,
    ExportFormat.xlsx => l.exportXlsxD,
    ExportFormat.csv => l.exportCsvD,
    ExportFormat.html => l.exportHtmlPageD,
    ExportFormat.md => l.exportMdAnyD,
    ExportFormat.mddx => l.exportMddxD,
  };

  String _why(AppLocalizations l, String key) => switch (key) {
    'exportNoPage' => l.exportNoPage,
    'exportOnlyDocs' => l.exportOnlyDocs,
    'exportOnlyBooks' => l.exportOnlyBooks,
    _ => l.exportOnlyTables,
  };

  String? _hint(AppLocalizations l, ExportFormat f) => switch (f) {
    ExportFormat.csv => l.exportCsvHint,
    ExportFormat.xlsx => l.exportXlsxHint,
    ExportFormat.html => l.exportHtmlPageHint,
    ExportFormat.mddx => l.exportMddxHint,
    ExportFormat.docx => l.exportDocxHint,
    ExportFormat.epub => l.exportEpubHint,
    ExportFormat.md => l.exportMdAnyHint,
    ExportFormat.pdf => null,
  };

  Future<void> _go({bool print = false}) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    setState(() => _busy = true);
    final db = await ref.read(databaseProvider.future);
    await _p.save(db, widget.module.id);
    ExportOutcome r;
    try {
      r = await ExportService.run(
        db,
        nexusId: widget.module.nexusRef,
        moduleId: widget.module.id,
        moduleName: widget.itemKey != null ? (widget.itemName ?? widget.module.name) : widget.module.name,
        itemKey: widget.itemKey,
        format: _fmt,
        prefs: _p,
        lang: lang,
      );
    } catch (_) {
      r = const ExportOutcome.fail('failed');
    }
    if (!mounted) return;
    navigator.pop();
    if (!r.ok) {
      messenger.showSnackBar(SnackBar(content: Text(r.code == 'empty' ? l10n.exportMarkdownEmpty : l10n.exportFailedMessage)));
      return;
    }
    final notes = [
      if (r.skipped.isNotEmpty) l10n.exportFormulaSkipped.replaceAll('{names}', r.skipped.join(', ')),
      if (r.moreTimelines > 0) l10n.exportMoreTimelines.replaceAll('{n}', '${r.moreTimelines}'),
      if (r.missing > 0) l10n.exportMediaMissing.replaceAll('{n}', '${r.missing}'),
    ];
    if (notes.isNotEmpty) messenger.showSnackBar(SnackBar(content: Text(notes.join(' · '))));
    if (print) {
      await Printing.layoutPdf(onLayout: (_) async => r.bytes!, name: r.name);
    } else {
      await Share.shareXFiles([XFile.fromData(r.bytes!, mimeType: r.mime, name: r.name)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final muted = context.ddx.textMuted;
    final scheme = Theme.of(context).colorScheme;
    final name = widget.itemKey != null ? (widget.itemName ?? widget.module.name) : widget.module.name;

    Widget card(_Card c) {
      final why = exportBlocked(c.f, _kind);
      final on = c.f == _fmt;
      return Semantics(
        selected: on,
        enabled: why == null,
        button: true,
        child: Opacity(
          opacity: why == null ? 1 : .5,
          child: Material(
            // picked: a tint and a ring — never a filled primary, which the quiet
            // description text cannot be read on in every theme
            color: on ? Color.alphaBlend(scheme.primary.withValues(alpha: .10), scheme.surface) : scheme.surfaceContainerHighest.withValues(alpha: .5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: on ? scheme.primary : Colors.transparent, width: 2),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: why == null && !_busy ? () => setState(() => _p = _p.copyWith(fmt: c.f.name)) : null,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(c.icon, size: 20, color: on ? scheme.primary : null),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _title(l10n, c.f),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      why != null ? _why(l10n, why) : _desc(l10n, c.f),
                      style: TextStyle(fontSize: 12, color: muted),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget select(String label, String value, List<(String, String)> opts, ValueChanged<String> onChanged) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        items: [for (final (v, t) in opts) DropdownMenuItem(value: v, child: Text(t))],
        onChanged: _busy ? null : (v) => v == null ? null : onChanged(v),
      ),
    );

    final hint = _hint(l10n, _fmt);
    final options = <Widget>[
      if (_fmt == ExportFormat.pdf) ...[
        if (widget.itemKey == null)
          select(l10n.exportScope, _p.scope, [
            ('page', l10n.exportScopePage),
            ('module', l10n.exportScopeModule),
          ], (v) => setState(() => _p = _p.copyWith(scope: v))),
        Row(
          children: [
            Expanded(
              child: select(l10n.exportPaper, _p.paper, const [
                ('A4', 'A4'),
                ('Letter', 'Letter'),
                ('A5', 'A5'),
              ], (v) => setState(() => _p = _p.copyWith(paper: v))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: select(l10n.exportOrientation, _p.orientation, [
                ('portrait', l10n.exportPortrait),
                ('landscape', l10n.exportLandscape),
              ], (v) => setState(() => _p = _p.copyWith(orientation: v))),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.exportHeaderFooter),
          value: _p.headerFooter,
          onChanged: _busy ? null : (v) => setState(() => _p = _p.copyWith(headerFooter: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.exportToc),
          value: _p.toc,
          onChanged: _busy ? null : (v) => setState(() => _p = _p.copyWith(toc: v)),
        ),
      ],
      if (_fmt == ExportFormat.md)
        select(l10n.exportScope, _p.mdScope, [
          ('module', l10n.exportScopeInside),
          ('nexus', l10n.exportScopeNexus),
        ], (v) => setState(() => _p = _p.copyWith(mdScope: v))),
      if (hint != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(hint, style: TextStyle(fontSize: 12, color: muted)),
        ),
    ];

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.exportTitle} — $name',
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, box) {
                  final cols = box.maxWidth >= 560 ? 4 : 2;
                  final w = (box.maxWidth - 8 * (cols - 1)) / cols;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _cards)
                        SizedBox(
                          width: w,
                          child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 92), child: card(c)),
                        ),
                    ],
                  );
                },
              ),
              ...options,
              const SizedBox(height: 16),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.exportWorking, style: TextStyle(color: muted), overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              // wraps to a column on a narrow phone rather than overflowing
              OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                spacing: 8,
                overflowSpacing: 6,
                children: [
                  TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(l10n.btnCancel)),
                  if (_fmt == ExportFormat.pdf)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _go(print: true),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: Text(l10n.exportPrint),
                    ),
                  FilledButton.icon(onPressed: _busy ? null : _go, icon: const Icon(Icons.ios_share, size: 18), label: Text(l10n.exportGo)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
