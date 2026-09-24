import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../data/dao/viewer_dao.dart';
import '../../../data/models/viewer_model.dart';
import '../../../data/services/wiki_service.dart';
import '../../../providers/db_providers.dart';
import '../../../widgets/row_menu.dart';
import '../component_registry.dart';
import '../core_components.dart';
import '../module_page.dart';
import 'graph_view.dart';
import 'node_canvas.dart';
import 'selection_views.dart';
import 'view_common.dart';

/// The Exhibitor's scene (EXE mod/exhibitor-scene.js): the one canvas whose
/// node positions are real rows (exhibit_node). A phone sees it as a
/// thumbnail; full screen pans and pinches, and a node drags to move.

class ExhNode {
  final int id;
  final int? parentId;
  final String type;
  final String? key;
  final String? label;
  final double x, y;
  final double? w, h;
  final String? color;
  final bool locked;
  const ExhNode(this.id, this.parentId, this.type, this.key, this.label, this.x, this.y, this.w, this.h, this.color,
      this.locked);

  /// The desktop's default sizes (EXH_BOX / EXH_NOTE / EXH_GROUP).
  Size get size => switch (type) {
        'group' => Size(w ?? 340, h ?? 230),
        'note' => Size(w ?? 170, h ?? 90),
        _ => Size(w ?? 168, h ?? 46),
      };
}

final exhibitSceneProvider = FutureProvider.autoDispose.family<List<ExhNode>, (int, int)>((ref, arg) async {
  final (moduleId, nexusId) = arg;
  final db = await ref.watch(databaseProvider.future);
  Future<List<Map<String, Object?>>> rows() =>
      db.rawQuery('SELECT * FROM exhibit_node WHERE module_ref=? AND hidden=0 ORDER BY z, id', [moduleId]);
  var r = await rows();
  // §4.3: a former Connector lays its filter results out once, as saved
  // rows, on the circle the old Connector computed at runtime.
  final seed = await db.rawQuery("SELECT ui_value FROM module_ui WHERE module_ref=? AND ui_key='seedScene'", [moduleId]);
  if (seed.isNotEmpty && seed.first['ui_value'] == '1') {
    if (r.isEmpty) {
      final dao = ViewerDao(db);
      final items = applyFilter(await dao.index(nexusId), await dao.getFilterDef(moduleId), moduleId);
      final radius = math.min(240, 90 + items.length * 18);
      await addExhibitNodes(db, moduleId, [
        for (var i = 0; i < items.length; i++)
          (
            key: items[i].key,
            x: radius * math.cos(2 * math.pi * i / math.max(1, items.length) - math.pi / 2),
            y: radius * math.sin(2 * math.pi * i / math.max(1, items.length) - math.pi / 2),
          ),
      ]);
      r = await rows();
    }
    await db.insert('module_ui', {'module_ref': moduleId, 'ui_key': 'seedScene', 'ui_value': '0'},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
  return [
    for (final n in r)
      ExhNode(
        n['id'] as int,
        n['parent_id'] as int?,
        n['node_type'] as String? ?? 'entity',
        n['linker_key'] as String?,
        n['label'] as String?,
        (n['x'] as num?)?.toDouble() ?? 0,
        (n['y'] as num?)?.toDouble() ?? 0,
        (n['w'] as num?)?.toDouble(),
        (n['h'] as num?)?.toDouble(),
        n['color'] as String?,
        (n['locked'] as int? ?? 0) != 0,
      ),
  ];
});

/// EXE addExhibitNodes: a key already in the scene is skipped, so a double
/// add is harmless. [key] null makes a free node of [type].
Future<void> addExhibitNodes(Database db, int moduleId, List<({String key, double x, double y})> nodes,
    {String type = 'entity', String? label}) async {
  await db.transaction((tx) async {
    final top = await tx.rawQuery('SELECT COALESCE(MAX(z),0) AS z FROM exhibit_node WHERE module_ref=?', [moduleId]);
    var z = (top.first['z'] as num?)?.toInt() ?? 0;
    for (final n in nodes) {
      if (n.key.isNotEmpty) {
        final has = await tx.rawQuery('SELECT 1 FROM exhibit_node WHERE module_ref=? AND linker_key=?', [moduleId, n.key]);
        if (has.isNotEmpty) continue;
      }
      await tx.insert('exhibit_node', {
        'module_ref': moduleId,
        'node_type': n.key.startsWith('file_') ? 'asset' : type,
        'linker_key': n.key.isEmpty ? null : n.key,
        'label': label,
        'x': n.x,
        'y': n.y,
        'z': ++z,
        // An element lands as a card, as on the desktop (exhNewNodeProps).
        'props': n.key.startsWith('cobj_') ? '{"display":"card"}' : null,
      });
    }
  });
}

class ExhibitorScene extends ConsumerStatefulWidget {
  final ComponentCtx ctx;
  final SelectionData data;
  const ExhibitorScene({super.key, required this.ctx, required this.data});

  @override
  ConsumerState<ExhibitorScene> createState() => _ExhibitorSceneState();
}

class _ExhibitorSceneState extends ConsumerState<ExhibitorScene> {
  /// Where a node is while it is being dragged; saved on release.
  final Map<int, Offset> _drag = {};
  final TransformationController _tc = TransformationController();

  (int, int) get _arg => (widget.ctx.source.id, widget.ctx.nexusId);

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Offset _pos(ExhNode n) => _drag[n.id] ?? Offset(n.x, n.y);

  /// Groups and notes resize from a corner grip in full screen; the desktop
  /// reads the same w/h (exhNodeSize) though it has no grip of its own.
  final Map<int, Size> _resize = {};
  Size _size(ExhNode n) => _resize[n.id] ?? n.size;
  static bool _resizable(ExhNode n) => !n.locked && (n.type == 'group' || n.type == 'note');

  String _title(ExhNode n, AppLocalizations l) =>
      n.label?.isNotEmpty == true ? n.label! : (n.key != null ? widget.data.nameOf(n.key!) : (n.type == 'group' ? l.exhGroup : l.exhNote));

  Future<void> _refresh() async => ref.invalidate(exhibitSceneProvider(_arg));

  Future<void> _add(String type, Rect world) async {
    final l = AppLocalizations.of(context)!;
    final db = await ref.read(databaseProvider.future);
    final c = world.center;
    if (type == 'entity') {
      if (!mounted) return;
      final it = await pickEntity(context, ref, widget.ctx.nexusId, title: l.exhAddElement);
      if (it == null) return;
      await addExhibitNodes(db, widget.ctx.source.id, [(key: it.key, x: c.dx - 84, y: c.dy - 23)]);
    } else {
      await addExhibitNodes(db, widget.ctx.source.id, [(key: '', x: c.dx - 85, y: c.dy - 45)],
          type: type, label: type == 'group' ? l.exhGroup : l.exhNote);
    }
    await _refresh();
  }

  void _menu(ExhNode n, List<ExhNode> all) {
    final l = AppLocalizations.of(context)!;
    final placed = [
      for (final o in all)
        if (o.key != null && o.id != n.id && widget.data.byKey[o.key!] != null) widget.data.byKey[o.key!]!,
    ];
    showRowMenu(context, title: _title(n, l), [
      if (n.key != null) RowAction(label: l.rowOpen, icon: Icons.open_in_new, onTap: () => openKey(context, ref, n.key!)),
      if (n.key != null && placed.isNotEmpty && widget.data.byKey[n.key!] != null)
        RowAction(
          label: l.connectorAddRelation,
          icon: Icons.add_link,
          onTap: () async {
            await addRelationDialog(context, ref, widget.ctx, [widget.data.byKey[n.key!]!, ...placed], from: n.key);
          },
        ),
      if (n.key == null)
        RowAction(
          label: l.btnEdit,
          icon: Icons.edit_outlined,
          onTap: () async {
            final v = await editTextSheet(context,
                title: _title(n, l), initial: n.label ?? '', nexusId: widget.ctx.nexusId, singleLine: n.type == 'group');
            if (v == null) return;
            final db = await ref.read(databaseProvider.future);
            await db.rawUpdate("UPDATE exhibit_node SET label=?, update_at=datetime('now') WHERE id=?", [v, n.id]);
            // A note's text may hold [[links]] (EXE wiki-sources.js 'exn').
            if (n.type == 'note') await WikiService.reindexSource(db, 'exn', n.id);
            await _refresh();
          },
        ),
      RowAction(
        label: l.exhRemoveFromScene,
        icon: Icons.remove_circle_outline,
        danger: true,
        onTap: () async {
          final db = await ref.read(databaseProvider.future);
          await db.delete('wiki_link', where: 'src_key=?', whereArgs: ['exn_${n.id}']);
          await db.delete('exhibit_node', where: 'id=?', whereArgs: [n.id]);
          await _refresh();
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final nodes = ref.watch(exhibitSceneProvider(_arg)).valueOrNull;
    if (nodes == null) return const SizedBox(height: 120);
    final byId = {for (final n in nodes) n.id: n};
    // A table's rows draw inside it, not on the canvas.
    final top = [
      for (final n in nodes)
        if (n.parentId == null || byId[n.parentId]?.type == 'group') n,
    ]..sort((a, b) => (a.type == 'group' ? 0 : 1) - (b.type == 'group' ? 0 : 1));
    final children = <int, List<ExhNode>>{};
    for (final n in nodes) {
      if (n.parentId != null && byId[n.parentId]?.type != 'group') (children[n.parentId!] ??= []).add(n);
    }

    var world = Rect.zero;
    for (final n in top) {
      world = world.expandToInclude(_pos(n) & _size(n));
    }
    world = world.inflate(80);
    final origin = world.topLeft;

    final keyed = {for (final n in top) if (n.key != null) n.key!: n};
    final edges = widget.data.among(keyed.keys.toSet());

    final tools = Row(children: [
      IconButton(tooltip: l.exhAddElement, icon: const Icon(Icons.add_box_outlined), onPressed: () => _add('entity', world)),
      IconButton(tooltip: l.exhAddNote, icon: const Icon(Icons.sticky_note_2_outlined), onPressed: () => _add('note', world)),
      IconButton(tooltip: l.exhAddGroup, icon: const Icon(Icons.crop_square), onPressed: () => _add('group', world)),
    ]);

    Widget nodeWidget(ExhNode n) {
      final p = _pos(n) - origin;
      final s = _size(n);
      final stroke = hexColor(n.color) ?? scheme.primary;
      final Widget body = switch (n.type) {
        'group' => Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: 0.6),
              border: Border.all(color: stroke, width: 1.5),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(8),
            alignment: Alignment.topLeft,
            child: Text(_title(n, l), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        'note' => Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              border: Border.all(color: stroke),
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.all(8),
            child: Text(_title(n, l), style: const TextStyle(fontSize: 12), overflow: TextOverflow.fade),
          ),
        _ => Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: n.key != null && widget.data.byKey[n.key!] == null ? scheme.error : stroke, width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Icon(itemKindIcon(widget.data.byKey[n.key]?.itemKind ?? ''), size: 14),
                const SizedBox(width: 4),
                Expanded(child: Text(_title(n, l), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              for (final c in children[n.id] ?? const <ExhNode>[])
                Text('· ${_title(c, l)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
            ]),
          ),
      };
      final rows = (children[n.id]?.length ?? 0);
      return Positioned(
        left: p.dx,
        top: p.dy,
        width: s.width,
        height: s.height + rows * 15,
        child: GestureDetector(
          onTap: n.key != null ? () => openKey(context, ref, n.key!) : null,
          onLongPress: () => _menu(n, nodes),
          onPanUpdate: n.locked ? null : (d) => setState(() => _drag[n.id] = _pos(n) + d.delta),
          onPanEnd: n.locked
              ? null
              : (_) async {
                  final at = _drag[n.id];
                  if (at == null) return;
                  final db = await ref.read(databaseProvider.future);
                  await db.rawUpdate(
                      "UPDATE exhibit_node SET x=?, y=?, update_at=datetime('now') WHERE id=?", [at.dx, at.dy, n.id]);
                  await _refresh();
                  if (mounted) setState(() => _drag.remove(n.id));
                },
          child: body,
        ),
      );
    }

    final canvas = SizedBox(
      width: world.width,
      height: world.height,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _EdgePainter(
              [
                for (final e in edges)
                  if (keyed[e.from] != null && keyed[e.to] != null)
                    (
                      (_pos(keyed[e.from]!) - origin) + _size(keyed[e.from]!).center(Offset.zero),
                      (_pos(keyed[e.to]!) - origin) + _size(keyed[e.to]!).center(Offset.zero),
                      e.label,
                    ),
              ],
              scheme,
            ),
          ),
        ),
        for (final n in top) nodeWidget(n),
        if (widget.ctx.fullScreen)
          for (final n in top.where(_resizable))
            Positioned(
              left: _pos(n).dx - origin.dx + _size(n).width - ResizeGrip.size / 2,
              top: _pos(n).dy - origin.dy + _size(n).height - ResizeGrip.size / 2,
              child: ResizeGrip(
                onDrag: (d) => setState(() {
                  final s = _size(n);
                  _resize[n.id] = Size((s.width + d.dx).clamp(60, 4000), (s.height + d.dy).clamp(40, 4000));
                }),
                onEnd: () async {
                  final s = _resize[n.id];
                  if (s == null) return;
                  final db = await ref.read(databaseProvider.future);
                  await db.rawUpdate(
                      "UPDATE exhibit_node SET w=?, h=?, update_at=datetime('now') WHERE id=?", [s.width, s.height, n.id]);
                  await _refresh();
                  if (mounted) setState(() => _resize.remove(n.id));
                },
              ),
            ),
      ]),
    );

    if (top.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [tools, EmptyHint(l.exhSceneEmpty)]);
    }
    if (widget.ctx.fullScreen) {
      return Column(children: [
        tools,
        Expanded(
          child: InteractiveViewer(
            transformationController: _tc,
            constrained: false,
            minScale: 0.2,
            maxScale: 3,
            boundaryMargin: const EdgeInsets.all(400),
            child: canvas,
          ),
        ),
      ]);
    }
    // On the page: the whole scene, fitted to the block.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.ctx.wide) tools,
      SizedBox(
        height: CanvasFrame.thumbHeight + 80,
        child: FittedBox(fit: BoxFit.contain, child: canvas),
      ),
    ]);
  }
}

class _EdgePainter extends CustomPainter {
  final List<(Offset, Offset, String)> lines;
  final ColorScheme scheme;
  _EdgePainter(this.lines, this.scheme);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = scheme.outline
      ..strokeWidth = 1.5;
    for (final (a, b, label) in lines) {
      canvas.drawLine(a, b, p);
      if (label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 160);
        tp.paint(canvas, (a + b) / 2 - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}
