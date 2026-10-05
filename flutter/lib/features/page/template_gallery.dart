import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/ddx_theme.dart';
import '../../data/models/module_model.dart';
import '../../data/services/page_template_service.dart';
import '../../data/services/preset_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../providers/db_providers.dart';
import 'component_registry.dart';
import 'page_providers.dart';

/// A new module's first page: its kind's ★ template (the desktop's
/// applyStartTemplate). A failure leaves the default layout, which the page
/// makes on first open anyway.
Future<void> applyStartTemplate(Database db, int moduleId, ModuleKind kind, String locale) async {
  try {
    final tpl = await PageTemplateService.defaultFor(kind.id, locale);
    if (tpl != null) await PageTemplateService.apply(db, moduleId, tpl);
  } catch (_) {}
}

/// "Use template…" from the page's ⋮ (APP docs/TEMPLATES.md §3.3): the
/// gallery for this kind; picking one replaces the page's layout — content
/// stays — with Undo right after.
Future<void> showTemplateGallery(BuildContext context, WidgetRef ref, ModuleModel module) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final pick = await pickPageTemplate(context, ref, nexusId: module.nexusRef, kind: module.kind, module: module);
  if (pick == null) return;
  final db = await ref.read(databaseProvider.future);
  final key = PageKey(module.id, null);
  final r = await PageTemplateService.apply(db, module.id, pick.tpl, fields: pick.fields);
  ref.invalidate(pageProvider(key));
  ref.invalidate(pageProvider(PageKey(module.id, '*')));
  if (r.dropped > 0) messenger.showSnackBar(SnackBar(content: Text(l10n.tplBorrowDropped.replaceAll('{n}', '${r.dropped}'))));
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.tplApplied),
      action: SnackBarAction(
        label: l10n.btnUndo,
        onPressed: () async {
          await PageTemplateService.restore(db, module.id, r.old);
          ref.invalidate(pageProvider(key));
        },
      ),
    ),
  );
}

typedef TemplatePick = ({PageTemplate tpl, bool fields, ModuleKind kind});

/// The template gallery (mockup 07-module-templates; the desktop's
/// hub/page-templates.js). With [module]: "Use template…" for that page, its
/// kind fixed and a "Save page as template…" card. Without: the create flow
/// from "New" — a row of kinds (the desktop's sidebar, folded for a phone)
/// and Create. Cards carry a thumbnail drawn from the template's own blocks;
/// the picked one is previewed block by block with the fields it brings.
Future<TemplatePick?> pickPageTemplate(BuildContext context, WidgetRef ref, {required int nexusId, required ModuleKind kind, ModuleModel? module}) async {
  final locale = Localizations.localeOf(context).languageCode;
  final all = await PageTemplateService.templates(locale);
  if (!context.mounted) return null;
  final r = await showModalBottomSheet<Object>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 1100),
    builder: (_) => _Gallery(nexusId: nexusId, kind: kind, module: module, all: all),
  );
  if (r == 'save' && module != null && context.mounted) {
    await showSaveTemplateDialog(context, ref, module);
    return null;
  }
  return r is TemplatePick ? r : null;
}

class _Gallery extends ConsumerStatefulWidget {
  const _Gallery({required this.nexusId, required this.kind, required this.module, required this.all});
  final int nexusId;
  final ModuleKind kind;
  final ModuleModel? module;
  final List<PageTemplate> all;

  @override
  ConsumerState<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends ConsumerState<_Gallery> {
  late ModuleKind _kind = widget.kind;
  List<PageTemplate> _mine = const [];
  String? _sel;
  bool _fields = true;

  bool get _create => widget.module == null;

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  Future<void> _loadMine() async {
    final db = await ref.read(databaseProvider.future);
    final mine = await PresetService.mine(db, widget.nexusId, _kind.id);
    if (mounted) setState(() => _mine = mine);
  }

  // the kind the gallery opened on leads the row, so its chip starts in view
  late final List<String> _kinds = <String>{
    widget.kind.id,
    for (final t in widget.all)
      if (t.kind != '') t.kind,
  }.toList();

  List<PageTemplate> _listFor(String kind) {
    final b = widget.all.where((t) => t.kind == kind).toList()..sort((x, y) => (y.isDefault ? 1 : 0) - (x.isDefault ? 1 : 0));
    return [...b, if (kind == _kind.id) ..._mine];
  }

  static List _fieldsOf(PageTemplate t) => (t.preset?['fields'] as List?) ?? const [];

  Future<void> _deleteMine(PageTemplate t) async {
    final l10n = AppLocalizations.of(context)!;
    if (!await showConfirmDialog(context, message: l10n.presetDeleteConfirm)) return;
    final db = await ref.read(databaseProvider.future);
    await PresetService.delete(db, int.parse(t.id.substring(2)));
    await _loadMine();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final muted = context.ddx.textMuted;
    final list = _listFor(_kind.id);
    final cur = list.where((t) => t.id == _sel).firstOrNull ?? list.where((t) => t.isDefault).firstOrNull ?? list.firstOrNull;
    final fields = cur == null ? const [] : _fieldsOf(cur);

    Widget label(String t) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        t.toUpperCase(),
        style: TextStyle(fontSize: 11, letterSpacing: .5, fontWeight: FontWeight.w600, color: muted),
      ),
    );

    Widget card(PageTemplate t) {
      final on = t.id == cur?.id;
      final own = t.id.startsWith('u:');
      return Material(
        color: on ? Color.alphaBlend(scheme.primary.withValues(alpha: .10), scheme.surface) : scheme.surfaceContainerHighest.withValues(alpha: .5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: on ? scheme.primary : Colors.transparent, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _sel = t.id),
          onLongPress: own ? () => _deleteMine(t) : null,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TemplateThumb(blocks: t.page),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (t.isDefault) ...[
                      Icon(Icons.star, size: 14, color: scheme.primary),
                      const SizedBox(width: 2),
                      Text(l10n.tplDefault, style: TextStyle(fontSize: 11, color: scheme.primary)),
                    ] else if (own)
                      Text(l10n.tplMine, style: TextStyle(fontSize: 11, color: scheme.primary)),
                  ],
                ),
                if (t.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      t.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    Widget grid() => LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 640
            ? 4
            : box.maxWidth >= 440
            ? 3
            : 2;
        final w = (box.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in list) SizedBox(width: w, child: card(t)),
            if (!_create)
              SizedBox(
                width: w,
                height: 150,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(context, 'save'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add),
                      const SizedBox(height: 4),
                      Text(l10n.tplSave, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );

    final preview = cur == null
        ? const SizedBox()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              label(l10n.tplModulePage),
              TemplateBlocks(blocks: cur.page),
              if (cur.itemPage.isNotEmpty) ...[label(l10n.tplItemPage), TemplateBlocks(blocks: cur.itemPage)],
              if (fields.isNotEmpty) ...[
                label(l10n.tplFieldsHead),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in fields)
                      if (f is Map) Chip(label: Text('${f['name'] ?? ''}'), visualDensity: VisualDensity.compact),
                  ],
                ),
              ],
            ],
          );

    final kinds = !_create
        ? null
        : SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final k in _kinds)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: k == _kind.id,
                      avatar: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: kindColor[ModuleKind.fromId(k)] ?? muted, borderRadius: BorderRadius.circular(3)),
                      ),
                      label: Text('${kindName(l10n, ModuleKind.fromId(k))} · ${l10n.tplKindCount.replaceAll('{n}', '${_listFor(k).length}')}'),
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() {
                          _kind = ModuleKind.fromId(k);
                          _sel = null;
                          _mine = const [];
                        });
                        _loadMine();
                      },
                    ),
                  ),
              ],
            ),
          );

    final heading = [
      Text(_create ? l10n.tplGallery : l10n.tplUse.replaceAll('…', ''), style: Theme.of(context).textTheme.titleMedium),
      if (!_create) Text(l10n.tplUseHint, style: TextStyle(fontSize: 12, color: muted)),
      const SizedBox(height: 8),
      ?kinds,
    ];

    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth >= 720;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...heading,
                  Expanded(
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ListView(padding: const EdgeInsets.only(right: 16, bottom: 12, top: 4), children: [grid()]),
                              ),
                              SizedBox(width: 340, child: SingleChildScrollView(child: preview)),
                            ],
                          )
                        : ListView(padding: const EdgeInsets.only(bottom: 12, top: 4), children: [grid(), const SizedBox(height: 6), preview]),
                  ),
                  const Divider(height: 1),
                  if (fields.isNotEmpty) SwitchListTile(contentPadding: EdgeInsets.zero, dense: true, title: Text(l10n.tplFields), value: _fields, onChanged: (v) => setState(() => _fields = v)),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.btnCancel)),
                      FilledButton(onPressed: cur == null ? null : () => Navigator.pop(context, (tpl: cur, fields: _fields, kind: _kind)), child: Text(_create ? l10n.btnCreate : l10n.btnApply)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

bool _tall(Object? id) => RegExp(r'\.(view|spotlight|map|board|graph|timeline|progress)$').hasMatch('${id ?? ''}');

/// A block list as a tiny diagram: a bar per block, columns side by side,
/// the kind's view (and the hero-like blocks) in the accent.
class TemplateThumb extends StatelessWidget {
  const TemplateThumb({super.key, required this.blocks});
  final List blocks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bar(Object? b) {
      final tall = b is Map && _tall(b['component']);
      return Container(
        height: tall ? 20 : 8,
        margin: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(color: tall ? scheme.primary.withValues(alpha: .45) : scheme.onSurface.withValues(alpha: .18), borderRadius: BorderRadius.circular(3)),
      );
    }

    return Container(
      height: 70,
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      // a long page is cut off at the thumbnail's edge, not overflowed
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          maxHeight: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final b in blocks.take(6))
                if (b is Map && b['type'] == 'columns')
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (i, col) in ((b['children'] as List?) ?? const []).take(3).indexed)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final c in (col is List ? col : const []).take(3)) bar(c)]),
                          ),
                        ),
                    ],
                  )
                else
                  bar(b),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same blocks, larger and named — each component's own label.
class TemplateBlocks extends StatelessWidget {
  const TemplateBlocks({super.key, required this.blocks});
  final List blocks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    Widget box(Object? b) {
      final m = b is Map ? b : const {};
      final id = '${m['component'] ?? ''}';
      final name = m['type'] == 'text' ? l10n.pbText : (components[id]?.label(l10n) ?? id);
      final big = RegExp(r'\.(view|spotlight)$').hasMatch(id);
      return Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: big ? 44 : 30),
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        alignment: Alignment.topLeft,
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: big ? scheme.primary.withValues(alpha: .55) : Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: big ? null : context.ddx.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in blocks)
          if (b is Map && b['type'] == 'columns')
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, col) in ((b['children'] as List?) ?? const []).indexed)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                      child: Column(children: [for (final c in (col is List ? col : const [])) box(c)]),
                    ),
                  ),
              ],
            )
          else
            box(b),
      ],
    );
  }
}

/// "Save page as template…" from the page's ⋮ — the module's look, view,
/// fields and page (not its content), kept in this vault as one of Mine.
Future<void> showSaveTemplateDialog(BuildContext context, WidgetRef ref, ModuleModel module) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final c = TextEditingController(text: module.name);
  final name = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(l10n.tplSave.replaceAll('…', '')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.nameField),
          onSubmitted: (v) => Navigator.pop(d, v.trim()),
        ),
        const SizedBox(height: 10),
        Text(l10n.savePresetHint, style: TextStyle(fontSize: 12, color: d.ddx.textMuted)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(l10n.btnCancel)),
        FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(l10n.btnSave)),
      ],
    ),
  );
  if (name == null) return;
  if (name.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.nameRequired)));
    return;
  }
  final db = await ref.read(databaseProvider.future);
  await PresetService.save(db, module.nexusRef, module.id, name);
  messenger.showSnackBar(SnackBar(content: Text(l10n.presetSaved)));
}
