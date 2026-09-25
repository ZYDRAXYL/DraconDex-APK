import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../data/dao/viewer_dao.dart';
import '../../../data/models/module_model.dart';
import '../../../data/models/viewer_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../providers/navigation_providers.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../hub/content/filter_editor.dart';
import '../component_registry.dart';
import '../module_page.dart';
import 'exhibitor_scene.dart';
import 'graph_view.dart';
import 'view_common.dart';

/// The Exhibitor's and the Manager's views: both are a saved filter over
/// the Nexus index (module_ui filterDef, V5.md §8.9), drawn several ways
/// (EXE mod/exhibitor.js, exhibitor-table.js, exhibitor-graph.js).

class Rel {
  final int id;
  final String from;
  final String to;
  final String label;
  final String? relType;
  final bool directed;
  const Rel(this.id, this.from, this.to, this.label, this.relType, this.directed);
}

class SelectionData {
  final List<IndexedItem> index;
  final Map<String, IndexedItem> byKey;
  final FilterDef def;
  final List<IndexedItem> items;
  final List<Rel> relations;
  final String groupBy;
  const SelectionData(this.index, this.byKey, this.def, this.items, this.relations, this.groupBy);

  String nameOf(String key) => byKey[key]?.name ?? key;

  /// Relations with both ends among [keys].
  List<Rel> among(Set<String> keys) => [for (final r in relations) if (keys.contains(r.from) && keys.contains(r.to)) r];
}

final selectionProvider = FutureProvider.autoDispose.family<SelectionData, (int, int)>((ref, arg) async {
  final (moduleId, nexusId) = arg;
  final db = await ref.watch(databaseProvider.future);
  final dao = ViewerDao(db);
  final index = await ref.watch(nexusIndexProvider(nexusId).future);
  final def = await dao.getFilterDef(moduleId);
  final rows = await db.rawQuery(
      'SELECT id, from_key, to_key, label, rel_type, directed FROM entity_relation WHERE nexus_ref=? ORDER BY id', [nexusId]);
  final g = await db.rawQuery("SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='boardGroupBy'", [moduleId]);
  return SelectionData(
    index,
    {for (final it in index) it.key: it},
    def,
    applyFilter(index, def, moduleId),
    [
      for (final r in rows)
        Rel(r['id'] as int, r['from_key'] as String, r['to_key'] as String, r['label'] as String? ?? '',
            r['rel_type'] as String?, (r['directed'] as int? ?? 1) != 0),
    ],
    g.isEmpty ? 'module' : (g.first['ui_value'] as String? ?? 'module'),
  );
});

void refreshSelection(WidgetRef ref, ComponentCtx ctx) {
  ref.invalidate(selectionProvider((ctx.source.id, ctx.nexusId)));
  ref.invalidate(filterDefProvider(ctx.source.id));
  ref.invalidate(relationsProvider(ctx.nexusId));
}

/// A module shows its own kind's icon; anything else its item kind's.
IconData itemIcon(IndexedItem it) =>
    it.itemKind == 'module' ? (moduleKindInfo[ModuleKind.fromId(it.moduleKind)]?.icon ?? Icons.folder_outlined) : itemKindIcon(it.itemKind);

IconData itemKindIcon(String itemKind) => switch (itemKind) {
      'module' => Icons.folder_outlined,
      'object' => Icons.category_outlined,
      'event' => Icons.timeline_outlined,
      'dialogue' => Icons.forum_outlined,
      'chapter' => Icons.menu_book_outlined,
      'chat' => Icons.chat_bubble_outline,
      _ => Icons.description_outlined,
    };

/// An Exhibitor or Manager block.
class SelectionView extends ConsumerWidget {
  final ComponentCtx ctx;
  const SelectionView({super.key, required this.ctx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final data = ref.watch(selectionProvider((ctx.source.id, ctx.nexusId))).valueOrNull;
    if (data == null) return const SizedBox(height: 48);
    final exhibitor = ctx.source.kind == ModuleKind.exhibitor;
    Future<void> editFilter() async {
      final edited = await showFilterEditor(
        context,
        initial: data.def,
        modules: data.index.where((i) => i.itemKind == 'module').toList(),
      );
      if (edited == null) return;
      final db = await ref.read(databaseProvider.future);
      await ViewerDao(db).setFilterDef(ctx.source.id, edited);
      refreshSelection(ref, ctx);
    }

    final bar = ctx.fullScreen
        ? const SizedBox.shrink()
        : ViewBar(
            title: data.def.isEmpty ? null : '${data.items.length}',
            actions: [
              if (exhibitor && ctx.preset != 'scene')
                IconButton(
                  tooltip: l.connectorAddRelation,
                  icon: const Icon(Icons.add_link),
                  onPressed: () => addRelationDialog(context, ref, ctx, data.items),
                ),
              if (ctx.preset == 'board')
                PopupMenuButton<String>(
                  tooltip: l.groupBy,
                  icon: const Icon(Icons.view_week_outlined),
                  initialValue: data.groupBy,
                  onSelected: (g) async {
                    final db = await ref.read(databaseProvider.future);
                    await db.insert('module_ui', {'module_ref': ctx.source.id, 'ui_key': 'boardGroupBy', 'ui_value': g},
                        conflictAlgorithm: ConflictAlgorithm.replace);
                    refreshSelection(ref, ctx);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'module', child: Text(l.groupModule)),
                    PopupMenuItem(value: 'kind', child: Text(l.labelKind)),
                    PopupMenuItem(value: 'tag', child: Text(l.labelTags)),
                  ],
                ),
              IconButton(
                tooltip: l.filterTitle,
                icon: Icon(data.def.isEmpty ? Icons.filter_alt_off_outlined : Icons.filter_alt_outlined),
                onPressed: editFilter,
              ),
            ],
          );
    if (ctx.preset == 'scene') {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        bar,
        if (ctx.fullScreen) Expanded(child: ExhibitorScene(ctx: ctx, data: data)) else ExhibitorScene(ctx: ctx, data: data),
      ]);
    }
    final Widget body;
    if (data.def.isEmpty) {
      body = KindEmptyState(module: ctx.source, note: l.viewerNoFilter, startLabel: l.filterTitle, onStart: editFilter);
    } else if (data.items.isEmpty) {
      body = EmptyHint(l.viewerNoResults);
    } else {
      body = switch (ctx.preset) {
        'graph' => _Graph(ctx: ctx, data: data),
        'cards' => _Cards(ctx: ctx, data: data),
        'board' => _Board(ctx: ctx, data: data),
        'edges' => _Edges(ctx: ctx, data: data),
        'list' => _List(ctx: ctx, data: data),
        _ => _Table(ctx: ctx, data: data),
      };
    }
    if (ctx.fullScreen && ctx.preset == 'graph') {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bar, Expanded(child: body)]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bar, body]);
  }
}

/// An item's own page: an element opens itself, an event or a dialogue its
/// module (EXE openViewerItem — they have no page of their own there).
void openItem(BuildContext context, WidgetRef ref, IndexedItem it) => openKey(context, ref, it.key);

class _Table extends ConsumerWidget {
  final ComponentCtx ctx;
  final SelectionData data;
  const _Table({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DataTable(
        headingRowHeight: 40,
        columnSpacing: 20,
        showCheckboxColumn: false,
        columns: [
          DataColumn(label: Text(l.labelName)),
          DataColumn(label: Text(l.groupModule)),
          DataColumn(label: Text(l.labelKind)),
          DataColumn(label: Text(l.labelTags)),
        ],
        rows: [
          for (final it in data.items)
            DataRow(
              onSelectChanged: (_) => openItem(context, ref, it),
              cells: [
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 10, color: hexColor(it.colorCode) ?? Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(it.name.isEmpty ? l.viewerUntitled : it.name, overflow: TextOverflow.ellipsis),
                  ),
                ])),
                DataCell(Text(it.moduleName)),
                DataCell(Icon(itemIcon(it), size: 18)),
                DataCell(Text(it.tags.map((t) => '#$t').join(' '))),
              ],
            ),
        ],
      ),
    );
  }
}

class _Cards extends ConsumerWidget {
  final ComponentCtx ctx;
  final SelectionData data;
  const _Cards({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return PageGrid(children: [
      for (final it in data.items)
        TileCard(
          leading: Icon(itemIcon(it), size: 18, color: hexColor(it.colorCode)),
          title: it.name.isEmpty ? l.viewerUntitled : it.name,
          subtitle: [it.moduleName, if (it.tags.isNotEmpty) it.tags.map((t) => '#$t').join(' ')].join('\n'),
          onTap: () => openItem(context, ref, it),
        ),
    ]);
  }
}

class _List extends ConsumerWidget {
  final ComponentCtx ctx;
  final SelectionData data;
  const _List({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Column(children: [
      for (final it in data.items)
        ListTile(
          dense: true,
          leading: Icon(itemIcon(it), size: 20, color: hexColor(it.colorCode)),
          title: Text(it.name.isEmpty ? l.viewerUntitled : it.name, overflow: TextOverflow.ellipsis),
          subtitle: Text(it.moduleName),
          onTap: () => openItem(context, ref, it),
        ),
    ]);
  }
}

/// Grouped columns (the pre-v5 Viewer board, mockup 33), side by side and
/// scrolled sideways on a phone.
class _Board extends ConsumerWidget {
  final ComponentCtx ctx;
  final SelectionData data;
  const _Board({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final groups = <String, (String, List<IndexedItem>)>{};
    for (final it in data.items) {
      final (k, label) = switch (data.groupBy) {
        'kind' => (it.itemKind, it.itemKind),
        'tag' => (it.tags.isEmpty ? '—' : it.tags.first, it.tags.isEmpty ? '—' : '#${it.tags.first}'),
        _ => ('m${it.moduleId}', it.moduleName),
      };
      (groups[k] ??= (label, [])).$2.add(it);
    }
    return BoardColumns(columns: [
      for (final g in groups.values)
        BoardColumn(
          title: g.$1,
          count: g.$2.length,
          children: [
            for (final it in g.$2)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: Icon(itemIcon(it), size: 18, color: hexColor(it.colorCode)),
                  title: Text(it.name.isEmpty ? l.viewerUntitled : it.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: data.groupBy == 'module' ? null : Text(it.moduleName, style: theme.textTheme.bodySmall),
                  onTap: () => openItem(context, ref, it),
                ),
              ),
          ],
        ),
    ]);
  }
}

/// Side-by-side columns that scroll sideways — every board preset uses it.
class BoardColumns extends StatelessWidget {
  final List<BoardColumn> columns;
  final double width;
  const BoardColumns({super.key, required this.columns, this.width = 240});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in columns)
              Container(
                width: width,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: c,
              ),
          ],
        ),
      );
}

class BoardColumn extends StatelessWidget {
  final String title;
  final int? count;
  final List<Widget> children;
  final Widget? trailing;
  const BoardColumn({super.key, required this.title, this.count, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(child: Text(title, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis)),
          if (count != null) Text('$count', style: theme.textTheme.labelSmall),
          ?trailing,
        ]),
      ),
      ...children,
    ]);
  }
}

class _Graph extends ConsumerWidget {
  final ComponentCtx ctx;
  final SelectionData data;
  const _Graph({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = {for (final it in data.items) it.key};
    return GraphView(
      fullScreen: ctx.fullScreen,
      height: CanvasFrame.thumbHeight + 80,
      nodes: [for (final it in data.items) GraphNode(it.key, it.name, color: hexColor(it.colorCode))],
      edges: [for (final r in data.among(keys)) GraphEdge(r.from, r.to, label: r.label, directed: r.directed)],
      onTap: (n) => openKey(context, ref, n.key),
    );
  }
}

/// The old Connector's edge list, with type and direction (EXE
/// buildExhibitorEdgesHtml).
class _Edges extends ConsumerWidget {
  final ComponentCtx ctx;
  final SelectionData data;
  const _Edges({required this.ctx, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final rels = data.among({for (final it in data.items) it.key});
    if (rels.isEmpty) return EmptyHint(l.connectorNoRelations);
    return Column(children: [
      for (final r in rels)
        ListTile(
          dense: true,
          title: Text('${data.nameOf(r.from)}  ${r.directed ? '→' : '—'}  ${data.nameOf(r.to)}'),
          subtitle: r.label.isEmpty ? null : Text(r.label),
          onTap: () => openKey(context, ref, r.to),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: l.btnDelete,
            onPressed: () async {
              if (!await showConfirmDialog(context, title: l.confirmDeleteTitle, message: l.confirmDeleteMessage)) return;
              final db = await ref.read(databaseProvider.future);
              await ViewerDao(db).deleteRelation(r.id);
              refreshSelection(ref, ctx);
            },
          ),
        ),
    ]);
  }
}

/// Adds a relation between two of [items] (EXE openExhibitorRelationModal).
Future<void> addRelationDialog(BuildContext context, WidgetRef ref, ComponentCtx ctx, List<IndexedItem> items,
    {String? from, String? to}) async {
  final l = AppLocalizations.of(context)!;
  if (items.length < 2) return;
  final label = TextEditingController();
  var directed = true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setLocal) {
        DropdownButtonFormField<String> pick(String? v, String hint, void Function(String?) set) =>
            DropdownButtonFormField<String>(
              initialValue: v,
              isExpanded: true,
              decoration: InputDecoration(labelText: hint),
              items: [
                for (final n in items)
                  DropdownMenuItem(value: n.key, child: Text(n.name.isEmpty ? l.viewerUntitled : n.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (x) => setLocal(() => set(x)),
            );
        return AlertDialog(
          title: Text(l.connectorAddRelation),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              pick(from, l.connectorFrom, (x) => from = x),
              pick(to, l.connectorTo, (x) => to = x),
              TextField(controller: label, decoration: InputDecoration(labelText: l.connectorLabel)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.relDirected),
                value: directed,
                onChanged: (v) => setLocal(() => directed = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: Text(l.btnCancel)),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(l.btnSave)),
          ],
        );
      },
    ),
  );
  final text = label.text.trim();
  label.dispose();
  if (ok != true || from == null || to == null || from == to) return;
  final db = await ref.read(databaseProvider.future);
  await db.insert(
    'entity_relation',
    {
      'nexus_ref': ctx.nexusId,
      'module_ref': ctx.source.id,
      'from_key': from,
      'to_key': to,
      'label': text.isEmpty ? null : text,
      'directed': directed ? 1 : 0,
    },
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );
  refreshSelection(ref, ctx);
}
