import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../data/dao/page_block_dao.dart';
import '../../data/models/module_model.dart';
import '../../providers/db_providers.dart';
import 'component_registry.dart';
import 'core_components.dart';
import 'page_providers.dart';

/// Arrange mode on a phone (APK-V3.md §10.4 — the user chose a drag-to-
/// reorder list): the page's top-level blocks as a reorderable list. A
/// `columns` block moves as ONE tile, and inside it each column reorders on
/// its own, so a column layout made on a desktop is never pulled apart.
///
/// An element page still on the shared layout arranges that layout — for
/// every element of the module — and says so; "Give this page its own
/// layout" splits it first.
class ArrangeList extends ConsumerWidget {
  final PageData page;
  final PageKey pageKey;

  const ArrangeList({super.key, required this.page, required this.pageKey});

  /// The page rows are written to: the shared layout while the element has
  /// not been split off it.
  String? get _writeKey => page.from == PageSource.shared ? '*' : pageKey.itemKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final top = page.top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  page.from == PageSource.shared ? l10n.pbArrangeShared : l10n.pbArrangeHint,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => ref.read(arrangeModeProvider(pageKey).notifier).state = false,
                child: Text(l10n.pbArrangeDone),
              ),
            ],
          ),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (from, to) => _move(ref, top[from].id, to),
          children: [
            for (var i = 0; i < top.length; i++)
              _ArrangeTile(key: ValueKey(top[i].id), page: page, pageKey: pageKey, block: top[i], index: i, writeKey: _writeKey),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.add),
            label: Text(l10n.pbAddBlock),
            onPressed: () => showAddBlockSheet(context, ref, page: page, pageKey: pageKey, writeKey: _writeKey),
          ),
        ),
      ],
    );
  }

  Future<void> _move(WidgetRef ref, int id, int to) async {
    final dao = await ref.read(pageBlockDaoProvider.future);
    await dao.move(id, to);
    ref.invalidate(pageProvider(pageKey));
  }
}

String blockLabel(AppLocalizations l10n, PageBlock b, [ModuleModel? source]) {
  String first(String? s) {
    final line = (s ?? '').split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    return line.length > 40 ? '${line.substring(0, 40)}…' : line;
  }

  switch (b.type) {
    case 'text':
      final f = first(b.content);
      return f.isEmpty ? l10n.pbText : '${l10n.pbText} · $f';
    case 'heading':
      return '${l10n.pbHeading} · ${first(b.content)}';
    case 'divider':
      return l10n.pbDivider;
    case 'image':
      return l10n.pbImage;
    case 'columns':
      return '${l10n.pbColumns} · ${(b.config['n'] as num?)?.toInt() ?? 2}';
    default:
      final def = components[b.component];
      final name = def?.label(l10n) ?? b.component ?? '?';
      return b.sourceKey == null ? name : '$name ↪ ${source?.name ?? b.sourceKey}';
  }
}

class _ArrangeTile extends ConsumerWidget {
  final PageData page;
  final PageKey pageKey;
  final PageBlock block;
  final int index;
  final String? writeKey;

  const _ArrangeTile({
    super.key,
    required this.page,
    required this.pageKey,
    required this.block,
    required this.index,
    required this.writeKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tile = ListTile(
      leading: ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_indicator)),
      title: Text(blockLabel(l10n, block), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: l10n.btnDelete,
        onPressed: () => deleteBlockWithUndo(context, ref, pageKey, block.id),
      ),
    );
    if (block.type != 'columns') return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3), child: tile);
    final cols = page.columnsOf(block);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile,
          for (var c = 0; c < cols.length; c++)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${l10n.pbColumn} ${c + 1}', style: Theme.of(context).textTheme.labelSmall),
                  ReorderableListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    onReorderItem: (from, target) async {
                      // Children of one columns block share a parent, so
                      // their order is among ALL its children: land next to
                      // the child now at the target place in this column.
                      final col = cols[c];
                      final moving = col[from];
                      final all = [for (final b in page.blocks) if (b.parentId == block.id) b];
                      final at = all.indexOf(col[target.clamp(0, col.length - 1)]);
                      final dao = await ref.read(pageBlockDaoProvider.future);
                      await dao.move(moving.id, at);
                      ref.invalidate(pageProvider(pageKey));
                    },
                    children: [
                      for (var i = 0; i < cols[c].length; i++)
                        ListTile(
                          key: ValueKey(cols[c][i].id),
                          dense: true,
                          leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator, size: 18)),
                          title: Text(blockLabel(l10n, cols[c][i]), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: l10n.btnDelete,
                            onPressed: () => deleteBlockWithUndo(context, ref, pageKey, cols[c][i].id),
                          ),
                        ),
                    ],
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(l10n.pbAddHere),
                      onPressed: () => showAddBlockSheet(context, ref,
                          page: page, pageKey: pageKey, writeKey: writeKey, parent: block, column: c),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The add-block picker (EXE arrange.js): the basic blocks, this page's own
/// components (a `once` one only while it is not on the page), and a view
/// borrowed from another module.
Future<void> showAddBlockSheet(
  BuildContext context,
  WidgetRef ref, {
  required PageData page,
  required PageKey pageKey,
  required String? writeKey,
  PageBlock? parent,
  int column = 0,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final m = page.module;
  final onPage = {for (final b in page.blocks) if (b.type == 'component' && b.sourceKey == null) b.component};
  final elementPage = pageKey.itemKey != null;
  final own = <String>[
    'core.properties',
    'core.related',
    if (elementPage) 'item.body',
    if (!elementPage && components.containsKey(kindViewId(m.kind))) kindViewId(m.kind),
  ].where((id) => !(components[id]!.once && onPage.contains(id))).toList();

  Future<void> add(NewBlock b) async {
    final dao = await ref.read(pageBlockDaoProvider.future);
    await dao.add(
      m.id,
      writeKey,
      NewBlock(
        type: b.type,
        component: b.component,
        content: b.content,
        sourceKey: b.sourceKey,
        parentId: parent?.id,
        config: parent == null ? b.config : {...?b.config, 'col': column},
      ),
    );
    ref.invalidate(pageProvider(pageKey));
  }

  final picked = await showModalBottomSheet<Future<void> Function()>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.75),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(leading: const Icon(Icons.notes), title: Text(l10n.pbText), onTap: () => Navigator.pop(sheet, () => add(const NewBlock(type: 'text')))),
            ListTile(leading: const Icon(Icons.title), title: Text(l10n.pbHeading), onTap: () => Navigator.pop(sheet, () => add(const NewBlock(type: 'heading')))),
            ListTile(leading: const Icon(Icons.horizontal_rule), title: Text(l10n.pbDivider), onTap: () => Navigator.pop(sheet, () => add(const NewBlock(type: 'divider')))),
            ListTile(leading: const Icon(Icons.image_outlined), title: Text(l10n.pbImage), onTap: () => Navigator.pop(sheet, () => add(const NewBlock(type: 'image')))),
            if (parent == null)
              ListTile(
                leading: const Icon(Icons.view_column_outlined),
                title: Text(l10n.pbColumns),
                onTap: () => Navigator.pop(sheet, () => add(const NewBlock(type: 'columns', config: {'n': 2}))),
              ),
            if (own.isNotEmpty) const Divider(),
            for (final id in own)
              ListTile(
                leading: Icon(components[id]!.kind == null ? Icons.widgets_outlined : moduleKindInfo[components[id]!.kind]!.icon),
                title: Text(components[id]!.label(l10n)),
                onTap: () => Navigator.pop(sheet, () => add(NewBlock(component: id))),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.call_received),
              title: Text(l10n.pbBorrow),
              onTap: () => Navigator.pop(sheet, () async {
                final source = await _pickBorrowSource(context, ref, m);
                if (source != null) {
                  await add(NewBlock(component: kindViewId(source.kind), sourceKey: 'module_${source.id}'));
                }
              }),
            ),
          ],
        ),
      ),
    ),
  );
  await picked?.call();
}

/// Another module of the Nexus whose view may be borrowed.
Future<ModuleModel?> _pickBorrowSource(BuildContext context, WidgetRef ref, ModuleModel host) async {
  final db = await ref.read(databaseProvider.future);
  final rows = await db.rawQuery(
      "SELECT m.*, uc.color_code FROM module m LEFT JOIN use_color uc ON m.color=uc.id WHERE m.nexus_ref=? AND m.id<>? AND m.kind<>'collector' ORDER BY m.name COLLATE NOCASE",
      [host.nexusRef, host.id]);
  final mods = [
    for (final r in rows)
      if (components[kindViewId(ModuleKind.fromId(r['kind'] as String))]?.borrow ?? false) ModuleModel.fromMap(r),
  ];
  if (!context.mounted) return null;
  return showModalBottomSheet<ModuleModel>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in mods)
              ListTile(
                leading: Icon(m.kindInfo.icon),
                title: Text(m.name),
                subtitle: Text(m.kindInfo.label),
                onTap: () => Navigator.pop(sheet, m),
              ),
          ],
        ),
      ),
    ),
  );
}
