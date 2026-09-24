import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/classifier/formula.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/dao/classifier_dao.dart';
import '../../../data/models/classifier_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../providers/navigation_providers.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/row_menu.dart';
import '../component_registry.dart';
import '../core_components.dart';
import 'graph_view.dart';
import 'view_common.dart';

/// The Classifier's four presets (EXE mod/classifier.js CLASSIFIER_VIEWS):
/// table, list·detail, relations, grid — one loader, one typed editor.

class ClsRelation {
  final int id;
  final String from;
  final String to;
  final String? label;
  final String? relType;
  const ClsRelation(this.id, this.from, this.to, this.label, this.relType);

  /// The field a relation-field row belongs to (rel_type `ctpl_<id>`).
  int? get field => relType != null && relType!.startsWith('ctpl_') ? int.tryParse(relType!.substring(5)) : null;
}

class ClsData {
  final List<ClassifierFieldModel> fields;
  final List<ClassifierItemModel> items;
  final Map<int, Map<int, String?>> values;
  final List<ClsRelation> relations;

  /// Names of every key a relation here points at.
  final Map<String, String> names;

  /// {object: {field: rows}} of the levelled fields.
  final Map<int, Map<int, List<ClassifierLevelModel>>> levels;
  const ClsData(this.fields, this.items, this.values, this.relations, this.names, [this.levels = const {}]);

  List<ClassifierLevelModel> levelsOf(int item, int field) => levels[item]?[field] ?? const [];

  Map<int, String?> valuesOf(int item) => values[item] ?? const {};

  List<ClsRelation> fieldRels(int item, int field) =>
      [for (final r in relations) if (r.from == 'cobj_$item' && r.field == field) r];

  /// A value as text, whatever its type.
  String text(ClassifierItemModel item, ClassifierFieldModel f, AppLocalizations l) {
    if (f.isLevelled) {
      // The desktop's folded summary: the last row's level (or condition),
      // and how many rows there are.
      final rows = levelsOf(item.id, f.id);
      if (rows.isEmpty) return '';
      final last = rows.last.levelLabel ?? rows.last.conditionValue ?? '';
      return last.isEmpty ? '${rows.length}' : '$last · ${rows.length}';
    }
    final raw = valuesOf(item.id)[f.id] ?? '';
    return switch (f.type) {
      'checkbox' => raw == '1' ? '✓' : '',
      'multi' => multiValue(raw).join(', '),
      'relation' => [for (final r in fieldRels(item.id, f.id)) names[r.to] ?? r.to].join(', '),
      'formula' => () {
          final r = Formula.valueOf(f.formulaField, [for (final x in fields) x.formulaField], valuesOf(item.id));
          return r.ok ? r.text : '⚠';
        }(),
      _ => raw,
    };
  }
}

final clsDataProvider = FutureProvider.autoDispose.family<ClsData, int>((ref, moduleId) async {
  final db = await ref.watch(databaseProvider.future);
  final dao = ClassifierDao(db);
  final fields = await dao.getFields(moduleId);
  final items = await dao.getItems(moduleId);
  final values = await dao.getModuleValues(moduleId);
  final rows = await db.rawQuery(
    "SELECT r.id, r.from_key, r.to_key, r.label, r.rel_type FROM entity_relation r "
    "JOIN classifier_object o ON r.from_key='cobj_'||o.id WHERE o.module_ref=? ORDER BY r.id",
    [moduleId],
  );
  final rels = [
    for (final r in rows)
      ClsRelation(r['id'] as int, r['from_key'] as String, r['to_key'] as String, r['label'] as String?,
          r['rel_type'] as String?),
  ];
  final names = <String, String>{for (final i in items) 'cobj_${i.id}': i.name};
  final nexus = await db.rawQuery('SELECT nexus_ref FROM module WHERE id=?', [moduleId]);
  if (nexus.isNotEmpty && rels.any((r) => !names.containsKey(r.to))) {
    for (final it in await ref.watch(nexusIndexProvider(nexus.first['nexus_ref'] as int).future)) {
      names[it.key] = it.name;
    }
  }
  final levels = fields.any((f) => f.isLevelled) ? await dao.getModuleLevels(moduleId) : const <int, Map<int, List<ClassifierLevelModel>>>{};
  return ClsData(fields, items, values, rels, names, levels);
});

void _refresh(WidgetRef ref, int moduleId) {
  ref.invalidate(clsDataProvider(moduleId));
  ref.invalidate(classifierFieldsProvider(moduleId));
  ref.invalidate(classifierItemsProvider(moduleId));
}

/// The view a Classifier block draws.
class ClassifierView extends ConsumerWidget {
  final ComponentCtx ctx;
  const ClassifierView({super.key, required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final m = ctx.source;
    final data = ref.watch(clsDataProvider(m.id)).valueOrNull;
    if (data == null) return const SizedBox(height: 48);
    final bar = ViewBar(actions: [
      IconButton(
        tooltip: l.classifierNewField,
        icon: const Icon(Icons.view_column_outlined),
        onPressed: () => editClsField(context, ref, m.id, null),
      ),
      IconButton(
        tooltip: l.classifierNewItem,
        icon: const Icon(Icons.add),
        onPressed: () async {
          final name = await askText(context, l.classifierNewItem, label: l.labelName);
          if (name == null) return;
          final db = await ref.read(databaseProvider.future);
          await ClassifierDao(db).createItem(moduleRef: m.id, name: name);
          _refresh(ref, m.id);
          ref.invalidate(nexusIndexProvider(m.nexusRef));
        },
      ),
    ]);
    final body = data.items.isEmpty
        ? EmptyHint(l.classifierNoItems)
        : switch (ctx.preset) {
            'table' => _ClsTable(ctx: ctx, data: data),
            'relationCat' => _ClsRelations(ctx: ctx, data: data),
            'grid' => _ClsGrid(ctx: ctx, data: data),
            _ => _ClsListDetail(ctx: ctx, data: data),
          };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bar, body]);
  }
}

void _itemMenu(BuildContext context, WidgetRef ref, ComponentCtx ctx, ClassifierItemModel item) {
  final l = AppLocalizations.of(context)!;
  showRowMenu(context, title: item.name, [
    RowAction(
        label: l.rowOpen,
        icon: Icons.open_in_new,
        onTap: () => openElement(context, ctx.nexusId, ctx.source.id, 'cobj_${item.id}')),
    RowAction(
      label: l.btnRename,
      icon: Icons.edit_outlined,
      onTap: () async {
        final name = await askText(context, l.btnRename, initial: item.name, label: l.labelName);
        if (name == null) return;
        final db = await ref.read(databaseProvider.future);
        await ClassifierDao(db).updateItem(item.id, name: name, note: item.note);
        _refresh(ref, ctx.source.id);
        ref.invalidate(nexusIndexProvider(ctx.nexusId));
      },
    ),
    RowAction(
      label: l.btnDelete,
      icon: Icons.delete_outline,
      danger: true,
      onTap: () async {
        if (!await showConfirmDialog(context, title: l.confirmDeleteTitle, message: l.confirmDeleteMessage)) return;
        final db = await ref.read(databaseProvider.future);
        await ClassifierDao(db).deleteItem(item.id);
        _refresh(ref, ctx.source.id);
        ref.invalidate(nexusIndexProvider(ctx.nexusId));
      },
    ),
  ]);
}

// ── table ────────────────────────────────────────────────────────────────

class _ClsTable extends ConsumerWidget {
  final ComponentCtx ctx;
  final ClsData data;
  const _ClsTable({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 64,
        columnSpacing: 20,
        columns: [
          DataColumn(label: Text(l.labelName, style: theme.textTheme.labelLarge)),
          for (final f in data.fields)
            DataColumn(
              numeric: f.type == 'number' || f.type == 'formula',
              label: InkWell(
                onTap: () => editClsField(context, ref, ctx.source.id, f),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(clsTypeIcon(f.type), size: 14),
                  const SizedBox(width: 4),
                  Text(f.description, style: theme.textTheme.labelLarge),
                ]),
              ),
            ),
        ],
        rows: [
          for (final item in data.items)
            DataRow(cells: [
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(item.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                onTap: () => openElement(context, ctx.nexusId, ctx.source.id, 'cobj_${item.id}'),
                onLongPress: () => _itemMenu(context, ref, ctx, item),
              ),
              for (final f in data.fields)
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(data.text(item, f, l), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  onTap: f.type == 'formula' ? null : () => editClsValue(context, ref, ctx.source.id, item, f, data),
                ),
            ]),
        ],
      ),
    );
  }
}

// ── list · detail ────────────────────────────────────────────────────────

class _ClsListDetail extends ConsumerStatefulWidget {
  final ComponentCtx ctx;
  final ClsData data;
  const _ClsListDetail({required this.ctx, required this.data});

  @override
  ConsumerState<_ClsListDetail> createState() => _ClsListDetailState();
}

class _ClsListDetailState extends ConsumerState<_ClsListDetail> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final ctx = widget.ctx;
    final l = AppLocalizations.of(context)!;
    String sub(ClassifierItemModel it) => [
          for (final f in data.fields.take(2))
            if (data.text(it, f, l) case final String v when v.isNotEmpty) '${f.description}: $v',
        ].join(' · ');
    if (!ctx.wide) {
      // A phone: each element opens in place; its page is one tap further.
      return Column(children: [
        for (final it in data.items)
          ExpansionTile(
            key: ValueKey(it.id),
            title: Text(it.name, overflow: TextOverflow.ellipsis),
            subtitle: sub(it).isEmpty ? null : Text(sub(it), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new, size: 18),
              tooltip: l.rowOpen,
              onPressed: () => openElement(context, ctx.nexusId, ctx.source.id, 'cobj_${it.id}'),
            ),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [ClsItemFields(moduleId: ctx.source.id, itemId: it.id)],
          ),
      ]);
    }
    final sel = data.items.where((i) => i.id == _selected).firstOrNull ?? data.items.first;
    return SizedBox(
      height: 420,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 260,
          child: ListView(children: [
            for (final it in data.items)
              ListTile(
                dense: true,
                selected: it.id == sel.id,
                title: Text(it.name, overflow: TextOverflow.ellipsis),
                subtitle: sub(it).isEmpty ? null : Text(sub(it), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => setState(() => _selected = it.id),
                onLongPress: () => _itemMenu(context, ref, ctx, it),
              ),
          ]),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: ListView(children: [
            ListTile(
              title: Text(sel.name, style: Theme.of(context).textTheme.titleMedium),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new, size: 18),
                tooltip: l.rowOpen,
                onPressed: () => openElement(context, ctx.nexusId, ctx.source.id, 'cobj_${sel.id}'),
              ),
            ),
            ClsItemFields(key: ValueKey(sel.id), moduleId: ctx.source.id, itemId: sel.id),
          ]),
        ),
      ]),
    );
  }
}

/// One element's fields, each tappable into its typed editor — the body of
/// list·detail and of an element's own page (EXE classifier-detail.js).
class ClsItemFields extends ConsumerWidget {
  final int moduleId;
  final int itemId;
  const ClsItemFields({super.key, required this.moduleId, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final data = ref.watch(clsDataProvider(moduleId)).valueOrNull;
    if (data == null) return const SizedBox(height: 24);
    final item = data.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return const SizedBox.shrink();
    if (data.fields.isEmpty) return EmptyHint(l.classifierNoFields);
    return Column(children: [
      for (final f in data.fields)
        if (f.isLevelled)
          ClsLevelTable(moduleId: moduleId, itemId: item.id, field: f, rows: data.levelsOf(item.id, f.id))
        else
        ListTile(
          dense: true,
          leading: Icon(clsTypeIcon(f.type), size: 18),
          title: Text(f.description, style: theme.textTheme.labelMedium),
          subtitle: _valueWidget(context, ref, data, item, f, l),
          trailing: f.type == 'checkbox'
              ? Checkbox(
                  value: data.valuesOf(item.id)[f.id] == '1',
                  onChanged: (v) => _set(ref, moduleId, item.id, f.id, v == true ? '1' : '0'),
                )
              : null,
          onTap: f.type == 'formula' || f.type == 'checkbox'
              ? null
              : () => editClsValue(context, ref, moduleId, item, f, data),
        ),
    ]);
  }

  Widget? _valueWidget(
      BuildContext context, WidgetRef ref, ClsData data, ClassifierItemModel item, ClassifierFieldModel f, AppLocalizations l) {
    if (f.type == 'checkbox') return null;
    if (f.type == 'relation') {
      final rels = data.fieldRels(item.id, f.id);
      if (rels.isEmpty) return const Text('—');
      return Wrap(spacing: 4, runSpacing: 2, children: [
        for (final r in rels)
          ActionChip(
            visualDensity: VisualDensity.compact,
            label: Text(data.names[r.to] ?? r.to),
            onPressed: () => openKey(context, ref, r.to),
          ),
      ]);
    }
    if (f.type == 'url') {
      final v = data.valuesOf(item.id)[f.id] ?? '';
      if (v.isEmpty) return const Text('—');
      return InkWell(
        onTap: () => launchUrl(Uri.parse(v), mode: LaunchMode.externalApplication),
        child: Text(v, style: TextStyle(color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline)),
      );
    }
    final t = data.text(item, f, l);
    return Text(t.isEmpty ? '—' : t, maxLines: f.type == 'textarea' ? 6 : 2, overflow: TextOverflow.ellipsis);
  }
}

// ── relations ────────────────────────────────────────────────────────────

class _ClsRelations extends ConsumerWidget {
  final ComponentCtx ctx;
  final ClsData data;
  const _ClsRelations({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final keys = {for (final i in data.items) 'cobj_${i.id}'};
    final inner = [for (final r in data.relations) if (keys.contains(r.to)) r];
    final fieldName = {for (final f in data.fields) f.id: f.description};
    String relLabel(ClsRelation r) => r.field != null ? (fieldName[r.field] ?? '') : (r.label ?? '');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GraphView(
        fullScreen: ctx.fullScreen,
        nodes: [
          for (final i in data.items) GraphNode('cobj_${i.id}', i.name, color: hexColor(i.colorCode ?? ctx.source.colorCode)),
        ],
        edges: [for (final r in inner) GraphEdge(r.from, r.to, label: relLabel(r))],
        onTap: (n) => openElement(context, ctx.nexusId, ctx.source.id, n.key),
      ),
      if (!ctx.fullScreen)
        if (data.relations.isEmpty)
          EmptyHint(l.clsNoRelations)
        else
          for (final r in data.relations)
            ListTile(
              dense: true,
              leading: const Icon(Icons.east, size: 16),
              title: Text('${data.names[r.from] ?? r.from}  →  ${data.names[r.to] ?? r.to}'),
              subtitle: relLabel(r).isEmpty ? null : Text(relLabel(r)),
              onTap: () => openKey(context, ref, r.to),
            ),
    ]);
  }
}

// ── grid ─────────────────────────────────────────────────────────────────

class _ClsGrid extends ConsumerWidget {
  final ComponentCtx ctx;
  final ClsData data;
  const _ClsGrid({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return PageGrid(children: [
      for (final it in data.items)
        TileCard(
          leading: Icon(Icons.circle, size: 10, color: hexColor(it.colorCode) ?? Theme.of(context).colorScheme.primary),
          title: it.name,
          subtitle: [
            for (final f in data.fields.take(3))
              if (data.text(it, f, l) case final String v when v.isNotEmpty) '${f.description}: $v',
          ].join('\n'),
          onTap: () => openElement(context, ctx.nexusId, ctx.source.id, 'cobj_${it.id}'),
          onLongPress: () => _itemMenu(context, ref, ctx, it),
        ),
    ]);
  }
}

// ── editing ──────────────────────────────────────────────────────────────

IconData clsTypeIcon(String type) => switch (type) {
      'textarea' => Icons.notes,
      'number' => Icons.pin_outlined,
      'date' => Icons.event_outlined,
      'select' => Icons.arrow_drop_down_circle_outlined,
      'multi' => Icons.checklist,
      'checkbox' => Icons.check_box_outlined,
      'url' => Icons.link,
      'relation' => Icons.share_outlined,
      'formula' => Icons.functions,
      _ => Icons.short_text,
    };

String clsTypeLabel(AppLocalizations l, String type) => switch (type) {
      'textarea' => l.clsTypeTextarea,
      'number' => l.clsTypeNumber,
      'date' => l.clsTypeDate,
      'select' => l.clsTypeSelect,
      'multi' => l.clsTypeMulti,
      'checkbox' => l.clsTypeCheckbox,
      'url' => l.clsTypeUrl,
      'relation' => l.clsTypeRelation,
      'formula' => l.clsTypeFormula,
      _ => l.clsTypeText,
    };

Future<void> _set(WidgetRef ref, int moduleId, int item, int field, String? value) async {
  final db = await ref.read(databaseProvider.future);
  await ClassifierDao(db).setValue(objectRef: item, templateRef: field, value: value);
  _refresh(ref, moduleId);
  ref.invalidate(classifierValuesProvider(item));
}

/// The date a field holds, "D/M/YYYY HH:MM" (EXE fmtDate) — or null.
({int d, int m, int y, int h, int mi})? parseClsDate(String? v) {
  final m = RegExp(r'^\s*(\d+)/(\d+)/(\d+)(?:\s+(\d+):(\d+))?\s*$').firstMatch(v ?? '');
  if (m == null) return null;
  return (
    d: int.parse(m[1]!),
    m: int.parse(m[2]!),
    y: int.parse(m[3]!),
    h: int.parse(m[4] ?? '0'),
    mi: int.parse(m[5] ?? '0'),
  );
}

/// The desktop's fmtDate: the time only when there is one.
String formatClsDate(int d, int m, int y, [int h = 0, int mi = 0]) {
  final ts = (h != 0 || mi != 0) ? ' ${'$h'.padLeft(2, '0')}:${'$mi'.padLeft(2, '0')}' : '';
  return '$d/$m/$y$ts';
}

/// Edits one value with the editor its type calls for (EXE
/// cls-field-types.js clsFieldValueHtml).
Future<void> editClsValue(BuildContext context, WidgetRef ref, int moduleId, ClassifierItemModel item,
    ClassifierFieldModel f, ClsData data) async {
  if (f.isLevelled) {
    // A levelled value is its rows: edit them in a sheet over the table.
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Consumer(builder: (context, ref, _) {
        final d = ref.watch(clsDataProvider(moduleId)).valueOrNull ?? data;
        return SingleChildScrollView(
          child: ClsLevelTable(moduleId: moduleId, itemId: item.id, field: f, rows: d.levelsOf(item.id, f.id)),
        );
      }),
    );
    return;
  }
  final l = AppLocalizations.of(context)!;
  final raw = data.valuesOf(item.id)[f.id] ?? '';
  final nexus = await _nexusOf(ref, moduleId);
  if (!context.mounted) return;
  switch (f.type) {
    case 'formula':
      return;
    case 'checkbox':
      return _set(ref, moduleId, item.id, f.id, raw == '1' ? '0' : '1');
    case 'text':
    case 'textarea':
      final v = await editTextSheet(context, title: f.description, initial: raw, nexusId: nexus, singleLine: f.type == 'text');
      if (v != null) await _set(ref, moduleId, item.id, f.id, v);
    case 'number':
    case 'url':
      final c = TextEditingController(text: raw);
      final v = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(f.description),
          content: TextField(
            controller: c,
            autofocus: true,
            keyboardType: f.type == 'number' ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.url,
            onSubmitted: (v) => Navigator.pop(d, v.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text(l.btnCancel)),
            FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(l.btnSave)),
          ],
        ),
      );
      c.dispose();
      if (v == null) return;
      if (f.type == 'number' && v.isNotEmpty && double.tryParse(v) == null) return;
      await _set(ref, moduleId, item.id, f.id, v);
    case 'date':
      final v = await _editDate(context, f.description, raw);
      if (v != null) await _set(ref, moduleId, item.id, f.id, v);
    case 'select':
      final v = await showDialog<String>(
        context: context,
        builder: (d) => SimpleDialog(title: Text(f.description), children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(d, ''), child: const Text('—')),
          for (final c in f.choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(d, c),
              child: Row(children: [
                Expanded(child: Text(c)),
                if (c == raw) const Icon(Icons.check, size: 18),
              ]),
            ),
        ]),
      );
      if (v != null) await _set(ref, moduleId, item.id, f.id, v);
    case 'multi':
      final picked = {...multiValue(raw)};
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => StatefulBuilder(
          builder: (d, setLocal) => AlertDialog(
            title: Text(f.description),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final c in f.choices)
                  CheckboxListTile(
                    dense: true,
                    value: picked.contains(c),
                    title: Text(c),
                    onChanged: (v) => setLocal(() => v == true ? picked.add(c) : picked.remove(c)),
                  ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d), child: Text(l.btnCancel)),
              FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.btnSave)),
            ],
          ),
        ),
      );
      if (ok == true) {
        // Keep the choices' own order, as the desktop does.
        await _set(ref, moduleId, item.id, f.id, jsonEncode([for (final c in f.choices) if (picked.contains(c)) c]));
      }
    case 'relation':
      await _editRelations(context, ref, moduleId, nexus, item, f);
  }
}

Future<int> _nexusOf(WidgetRef ref, int moduleId) async {
  final db = await ref.read(databaseProvider.future);
  final r = await db.rawQuery('SELECT nexus_ref FROM module WHERE id=?', [moduleId]);
  return r.isEmpty ? 0 : r.first['nexus_ref'] as int;
}

Future<String?> _editDate(BuildContext context, String title, String raw) async {
  final l = AppLocalizations.of(context)!;
  final v = parseClsDate(raw);
  final cs = [
    for (final n in [v?.d, v?.m, v?.y, v?.h, v?.mi]) TextEditingController(text: n == null ? '' : '$n'),
  ];
  final labels = [l.dateDay, l.dateMonth, l.dateYear, l.dateHour, l.dateMinute];
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < 5; i++)
          SizedBox(
            width: i == 2 ? 88 : 56,
            child: TextField(
              controller: cs[i],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: labels[i], isDense: true),
            ),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.btnClear)),
        TextButton(onPressed: () => Navigator.pop(d), child: Text(l.btnCancel)),
        FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.btnSave)),
      ],
    ),
  );
  final n = [for (final c in cs) int.tryParse(c.text.trim()) ?? 0];
  for (final c in cs) {
    c.dispose();
  }
  if (ok == null) return null;
  // Day, month and year together, or nothing — a half date no reader could
  // parse back saves as empty (EXE saveClassifierAttrDate).
  if (ok == false || n[0] == 0 || n[1] == 0 || n[2] == 0) return '';
  return formatClsDate(n[0], n[1], n[2], n[3], n[4]);
}

Future<void> _editRelations(
    BuildContext context, WidgetRef ref, int moduleId, int nexus, ClassifierItemModel item, ClassifierFieldModel f) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheet) => Consumer(builder: (sheet, ref, _) {
      final l = AppLocalizations.of(sheet)!;
      final data = ref.watch(clsDataProvider(moduleId)).valueOrNull;
      final rels = data?.fieldRels(item.id, f.id) ?? const [];
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('${item.name} · ${f.description}', style: Theme.of(sheet).textTheme.titleMedium),
          ),
          for (final r in rels)
            ListTile(
              dense: true,
              title: Text(data?.names[r.to] ?? r.to),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: l.btnDelete,
                onPressed: () async {
                  final db = await ref.read(databaseProvider.future);
                  await ClassifierDao(db).deleteRelation(r.id);
                  _refresh(ref, moduleId);
                },
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(l.clsAddLink),
            onTap: () async {
              final picked = await pickEntity(sheet, ref, nexus, title: f.description, where: (it) => it.key != 'cobj_${item.id}');
              if (picked == null) return;
              final db = await ref.read(databaseProvider.future);
              await ClassifierDao(db).addFieldRelation(item.id, f.id, picked.key);
              _refresh(ref, moduleId);
            },
          ),
          const SizedBox(height: 8),
        ]),
      );
    }),
  );
}

/// Adds a field ([f] null) or edits one: name, type, and the type's own
/// settings — choices for select/multi, the expression for a formula.
Future<void> editClsField(BuildContext context, WidgetRef ref, int moduleId, ClassifierFieldModel? f) async {
  final l = AppLocalizations.of(context)!;
  final name = TextEditingController(text: f?.description ?? '');
  final choices = TextEditingController(text: f?.choices.join('\n') ?? '');
  final expr = TextEditingController(text: f?.opts['expr'] as String? ?? '');
  var type = f?.type ?? 'text';
  var levelable = f?.levelable ?? false, hasCondition = f?.hasCondition ?? false;
  final result = await showDialog<String>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setLocal) => AlertDialog(
        title: Text(f == null ? l.classifierNewField : l.clsEditField),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: f == null, decoration: InputDecoration(labelText: l.labelName)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: InputDecoration(labelText: l.clsFieldType),
              items: [
                for (final t in ClassifierFieldModel.types)
                  DropdownMenuItem(
                    value: t,
                    child: Row(children: [Icon(clsTypeIcon(t), size: 18), const SizedBox(width: 8), Text(clsTypeLabel(l, t))]),
                  ),
              ],
              onChanged: (v) => setLocal(() => type = v ?? type),
            ),
            if (type == 'select' || type == 'multi') ...[
              const SizedBox(height: 12),
              TextField(
                controller: choices,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(labelText: l.clsChoices, alignLabelWithHint: true),
              ),
            ],
            if (type == 'formula') ...[
              const SizedBox(height: 12),
              TextField(controller: expr, decoration: InputDecoration(labelText: l.clsTypeFormula, hintText: l.clsFormulaHint)),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: levelable || hasCondition,
              title: Text(l.clsLevelAndCondition),
              subtitle: Text(l.clsLevelAndConditionHint, style: Theme.of(d).textTheme.bodySmall),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.clsLevelable),
                  value: levelable,
                  onChanged: (v) => setLocal(() => levelable = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.clsCondition),
                  value: hasCondition,
                  onChanged: (v) => setLocal(() => hasCondition = v),
                ),
              ],
            ),
          ]),
        ),
        actions: [
          if (f != null)
            TextButton(
              onPressed: () => Navigator.pop(d, 'delete'),
              child: Text(l.btnDelete, style: TextStyle(color: Theme.of(d).colorScheme.error)),
            ),
          TextButton(onPressed: () => Navigator.pop(d), child: Text(l.btnCancel)),
          FilledButton(onPressed: () => Navigator.pop(d, 'save'), child: Text(l.btnSave)),
        ],
      ),
    ),
  );
  final n = name.text.trim();
  final ch = [
    for (final c in choices.text.split('\n'))
      if (c.trim().isNotEmpty) c.trim(),
  ];
  final ex = expr.text.trim();
  name.dispose();
  choices.dispose();
  expr.dispose();
  if (result == null) return;
  final db = await ref.read(databaseProvider.future);
  final dao = ClassifierDao(db);
  if (result == 'delete') {
    if (!context.mounted) return;
    if (!await showConfirmDialog(context, title: l.confirmDeleteTitle, message: l.classifierDeleteFieldWarning)) return;
    await dao.deleteField(f!.id);
  } else {
    if (n.isEmpty) return;
    // Keep whatever else the options held (the desktop may store more).
    final opts = {...?f?.opts};
    if (type == 'select' || type == 'multi') opts['choices'] = ch;
    if (type == 'formula') opts['expr'] = ex;
    final options = opts.isEmpty ? null : jsonEncode(opts);
    if (f == null) {
      final id = await dao.createField(moduleRef: moduleId, description: n, attributeType: type);
      await dao.updateField(id, description: n, type: type, options: options, levelable: levelable, hasCondition: hasCondition);
    } else {
      await dao.updateField(f.id, description: n, type: type, options: options, levelable: levelable, hasCondition: hasCondition);
    }
  }
  _refresh(ref, moduleId);
}

// ── level & condition rows ───────────────────────────────────────────────

/// A levelled field's rows on one element (EXE classifier-detail.js
/// renderClassifierLevelTableHtml): the columns its flags ask for, reordered
/// by the handle, each row edited in a sheet, inserted above/below or
/// deleted from its menu.
class ClsLevelTable extends ConsumerWidget {
  final int moduleId;
  final int itemId;
  final ClassifierFieldModel field;
  final List<ClassifierLevelModel> rows;
  const ClsLevelTable({super.key, required this.moduleId, required this.itemId, required this.field, required this.rows});

  static String columnLabel(AppLocalizations l, String c) => switch (c) {
    'level_label' => l.levelColLevel,
    'condition_value' => l.clsCondition,
    _ => l.levelColInfo,
  };

  Future<ClassifierDao> _dao(WidgetRef ref) async => ClassifierDao(await ref.read(databaseProvider.future));

  void _done(WidgetRef ref) {
    _refresh(ref, moduleId);
    ref.invalidate(classifierValuesProvider(itemId));
  }

  /// Appends a row, then moves it to [at] (EXE insertClassifierLevel).
  Future<void> _insert(BuildContext context, WidgetRef ref, int at) async {
    final dao = await _dao(ref);
    final id = await dao.createLevel(itemId, field.id);
    final ids = [for (final r in rows) r.id]..insert(at.clamp(0, rows.length), id);
    await dao.moveLevels(itemId, field.id, ids);
    _done(ref);
    if (context.mounted) await _edit(context, ref, id, null);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, int id, ClassifierLevelModel? row) async {
    final l = AppLocalizations.of(context)!;
    final cols = field.levelColumns;
    final ctl = {for (final c in cols) c: TextEditingController(text: row?[c] ?? '')};
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(field.description),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final c in cols)
                TextField(
                  controller: ctl[c],
                  autofocus: c == cols.first,
                  minLines: 1,
                  maxLines: c == 'info_value' ? 5 : 1,
                  decoration: InputDecoration(labelText: columnLabel(l, c)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(l.btnCancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.btnSave)),
        ],
      ),
    );
    final values = {for (final e in ctl.entries) e.key: e.value.text.trim()};
    for (final c in ctl.values) {
      c.dispose();
    }
    if (ok != true) return;
    final dao = await _dao(ref);
    for (final e in values.entries) {
      if (e.value != (row?[e.key] ?? '')) await dao.updateLevelField(id, e.key, e.value);
    }
    _done(ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cols = field.levelColumns;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.format_list_numbered, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(child: Text(field.description, style: theme.textTheme.labelMedium)),
              TextButton.icon(icon: const Icon(Icons.add, size: 18), label: Text(l.levelAddRow), onPressed: () => _insert(context, ref, rows.length)),
            ],
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 34, bottom: 4),
              child: Text(l.levelNoRows, style: theme.textTheme.bodySmall),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (from, to) async {
                final ids = [for (final r in rows) r.id];
                ids.insert(to, ids.removeAt(from));
                await (await _dao(ref)).moveLevels(itemId, field.id, ids);
                _done(ref);
              },
              children: [
                for (final (i, r) in rows.indexed)
                  ListTile(
                    key: ValueKey(r.id),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator, size: 20)),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          for (final (j, c) in cols.where((c) => c != 'info_value').indexed) ...[
                            if (j > 0) const TextSpan(text: '  ·  '),
                            TextSpan(
                              text: (r[c] ?? '').isEmpty ? '—' : r[c],
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                          if (cols.length > 1) const TextSpan(text: '  '),
                          TextSpan(text: r.infoValue ?? ''),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _edit(context, ref, r.id, r),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        switch (v) {
                          case 'above':
                            await _insert(context, ref, i);
                          case 'below':
                            await _insert(context, ref, i + 1);
                          case 'delete':
                            if (!await showConfirmDialog(context, message: l.confirmDeleteLevelRow)) return;
                            await (await _dao(ref)).deleteLevel(r.id);
                            _done(ref);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'above', child: Text(l.clsInsertAbove)),
                        PopupMenuItem(value: 'below', child: Text(l.clsInsertBelow)),
                        PopupMenuItem(value: 'delete', child: Text(l.btnDelete)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
