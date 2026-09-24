import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../data/dao/designer_dao.dart';
import '../../../data/models/designer_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';
import '../../../providers/navigation_providers.dart';
import '../../../widgets/row_menu.dart';
import '../component_registry.dart';
import '../core_components.dart';
import 'graph_view.dart';
import 'node_canvas.dart';
import 'sketcher_views.dart';
import 'view_common.dart';

/// The Designer's three presets (EXE mod/designer.js DESIGNER_VIEWS):
/// canvas, outline, matrix — and its comic pages (designer-comic.js): a
/// panel shows a Sketcher page, a balloon speaks for someone, and both carry
/// a reading order.

const _glyph = {
  'box': '▭', 'rounded': '▢', 'circle': '○', 'ellipse': '⬭', 'pill': '⬬', 'diamond': '◇', //
  'hexagon': '⬡', 'parallelogram': '▰', 'triangle': '△', 'star': '☆', 'cross': '✚', //
  'note': '▤', 'text': 'T', 'panel': '▣', 'balloon': '💬',
};

/// The shapes the phone adds; any other one the desktop made still draws.
const _addShapes = ['box', 'ellipse', 'diamond', 'note', 'panel', 'balloon'];

Size designNodeSize(DesignNodeModel n) => switch (n.shape) {
      'panel' => Size(n.w ?? 240, n.h ?? 160),
      'balloon' => Size(n.w ?? 170, n.h ?? 70),
      'circle' => Size(n.w ?? 80, n.h ?? 80),
      _ => Size(n.w ?? 150, n.h ?? 56),
    };

String designNodeName(DesignNodeModel n) => n.text?.isNotEmpty == true ? n.text! : (_glyph[n.shape] ?? '▭');

class DesignerView extends ConsumerStatefulWidget {
  final ComponentCtx ctx;
  const DesignerView({super.key, required this.ctx});

  @override
  ConsumerState<DesignerView> createState() => _DesignerViewState();
}

class _DesignerViewState extends ConsumerState<DesignerView> {
  /// The node a link starts from; the next tap on a node ends it.
  int? _linkFrom;
  bool _showOrder = true;

  int get _id => widget.ctx.source.id;

  void _refresh() {
    ref.invalidate(designNodesProvider(_id));
    ref.invalidate(designEdgesProvider(_id));
  }

  Future<DesignerDao> _dao() async => DesignerDao(await ref.read(databaseProvider.future));

  Future<void> _add(List<DesignNodeModel> nodes) async {
    final l = AppLocalizations.of(context)!;
    final shape = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (s) => SafeArea(
        child: Wrap(children: [
          for (final sh in _addShapes)
            ListTile(
              leading: Text(_glyph[sh]!, style: const TextStyle(fontSize: 20)),
              title: Text(switch (sh) { 'panel' => l.dgPanel, 'balloon' => l.dgBalloon, _ => sh }),
              onTap: () => Navigator.pop(s, sh),
            ),
        ]),
      ),
    );
    if (shape == null) return;
    // Below everything already there, so a new node never covers another.
    final bottom = nodes.fold<double>(0, (m, n) => n.y + designNodeSize(n).height > m ? n.y + designNodeSize(n).height : m);
    final left = nodes.isEmpty ? 0.0 : nodes.map((n) => n.x).reduce((a, b) => a < b ? a : b);
    await (await _dao()).createNode(moduleRef: _id, x: left, y: nodes.isEmpty ? 0 : bottom + 30, shape: shape);
    _refresh();
  }

  Future<void> _edit(DesignNodeModel n) async {
    final l = AppLocalizations.of(context)!;
    final v = await editTextSheet(context, title: l.designerNodeText, initial: n.text ?? '', nexusId: widget.ctx.nexusId);
    if (v == null) return;
    await (await _dao()).updateNode(n.id, text: v, shape: n.shape);
    _refresh();
  }

  void _menu(DesignNodeModel n) {
    final l = AppLocalizations.of(context)!;
    showRowMenu(context, title: designNodeName(n), [
      RowAction(label: l.btnEdit, icon: Icons.edit_outlined, onTap: () => _edit(n)),
      RowAction(label: l.dgLinkFrom, icon: Icons.east, onTap: () => setState(() => _linkFrom = n.id)),
      if (n.shape == 'panel' || n.shape == 'balloon')
        RowAction(
          label: n.shape == 'panel' ? l.dgPanelShows : l.dgBalloonSpeaker,
          icon: n.shape == 'panel' ? Icons.image_outlined : Icons.person_outline,
          onTap: () async {
            final it = await pickEntity(context, ref, widget.ctx.nexusId,
                where: n.shape == 'panel' ? (it) => it.key.startsWith('skpg_') : null);
            if (it == null) return;
            await (await _dao()).setLinker(n.id, it.key);
            _refresh();
          },
        ),
      if (n.linkerKey != null) RowAction(label: l.rowOpen, icon: Icons.open_in_new, onTap: () => openKey(context, ref, n.linkerKey!)),
      RowAction(
        label: l.btnDelete,
        icon: Icons.delete_outline,
        danger: true,
        onTap: () async {
          await (await _dao()).deleteNode(n.id);
          _refresh();
        },
      ),
    ]);
  }

  Future<void> _tap(DesignNodeModel n) async {
    final from = _linkFrom;
    if (from == null) return _edit(n);
    setState(() => _linkFrom = null);
    if (from == n.id) return;
    await (await _dao()).addEdge(moduleRef: _id, fromRef: from, toRef: n.id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final nodes = ref.watch(designNodesProvider(_id)).valueOrNull;
    final edges = ref.watch(designEdgesProvider(_id)).valueOrNull;
    if (nodes == null || edges == null) return const SizedBox(height: 48);
    final comic = nodes.any((n) => n.shape == 'panel' || n.shape == 'balloon');
    final bar = ViewBar(actions: [
      if (_linkFrom != null)
        TextButton.icon(
          onPressed: () => setState(() => _linkFrom = null),
          icon: const Icon(Icons.close, size: 18),
          label: Text(l.designerLinkCancel),
        ),
      if (comic && widget.ctx.preset != 'matrix') ...[
        IconButton(
          tooltip: l.dgNumberByPosition,
          icon: const Icon(Icons.format_list_numbered),
          onPressed: () async {
            await (await _dao()).renumberReadOrder(_id);
            _refresh();
          },
        ),
        IconButton(
          tooltip: l.dgShowOrder,
          isSelected: _showOrder,
          icon: const Icon(Icons.looks_one_outlined),
          onPressed: () => setState(() => _showOrder = !_showOrder),
        ),
      ],
      IconButton(tooltip: l.designerNewNode, icon: const Icon(Icons.add), onPressed: () => _add(nodes)),
    ]);
    final Widget body;
    if (nodes.isEmpty) {
      body = EmptyHint(l.designerEmpty);
    } else {
      body = switch (widget.ctx.preset) {
        'outline' => _outline(nodes, edges),
        'matrix' => _matrix(nodes, edges),
        _ => _canvas(nodes, edges),
      };
    }
    final hint = _linkFrom == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.designerLinkHint, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          );
    if (widget.ctx.fullScreen) return Column(children: [bar, hint, Expanded(child: body)]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bar, hint, body]);
  }

  Widget _canvas(List<DesignNodeModel> nodes, List<DesignEdgeModel> edges) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget box(DesignNodeModel n) {
      final col = hexColor(n.color) ?? scheme.primary;
      final sel = _linkFrom == n.id;
      final border = Border.all(color: sel ? scheme.primary : col.withValues(alpha: 0.8), width: sel ? 3 : 1.5);
      final Widget inner = switch (n.shape) {
        'panel' => Container(
            decoration: BoxDecoration(color: scheme.surface, border: border, borderRadius: BorderRadius.circular(4)),
            clipBehavior: Clip.antiAlias,
            child: Stack(fit: StackFit.expand, children: [
              if (n.linkerKey?.startsWith('skpg_') == true)
                SketchThumb(pageId: int.tryParse(n.linkerKey!.substring(5)) ?? 0),
              if (n.text?.isNotEmpty == true)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: scheme.surface.withValues(alpha: 0.85),
                    padding: const EdgeInsets.all(4),
                    child: Text(n.text!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  ),
                ),
            ]),
          ),
        'balloon' => Container(
            decoration: BoxDecoration(color: scheme.surface, border: border, borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (n.linkerKey != null)
                Consumer(builder: (c, r, _) {
                  final name = r.watch(nexusIndexProvider(widget.ctx.nexusId)).valueOrNull?.where((it) => it.key == n.linkerKey).firstOrNull?.name;
                  return name == null ? const SizedBox.shrink() : Text(name, style: theme.textTheme.labelSmall?.copyWith(color: col));
                }),
              Text(n.text?.isNotEmpty == true ? n.text! : '…', maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ]),
          ),
        _ => Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              border: border,
              borderRadius: switch (n.shape) {
                'ellipse' || 'circle' || 'pill' => BorderRadius.circular(60),
                'box' => BorderRadius.circular(2),
                _ => BorderRadius.circular(8),
              },
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            child: Text(
              n.shape == 'diamond' || n.shape == 'note' ? '${_glyph[n.shape]} ${n.text ?? ''}' : (n.text ?? ''),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
      };
      if (!_showOrder || n.readOrder == null) return inner;
      return Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: inner),
        Positioned(
          left: -8,
          top: -8,
          child: CircleAvatar(radius: 11, backgroundColor: scheme.primary, child: Text('${n.readOrder}', style: TextStyle(fontSize: 11, color: scheme.onPrimary))),
        ),
      ]);
    }

    final byId = {for (final n in nodes) n.id: n};
    return NodeCanvas(
      fullScreen: widget.ctx.fullScreen,
      nodes: [for (final n in nodes) CanvasNode(n.id, Offset(n.x, n.y), designNodeSize(n), box(n))],
      links: [for (final e in edges) CanvasLink(e.fromRef, e.toRef, label: e.label)],
      onTap: (id) => _tap(byId[id]!),
      onLongPress: (id) => _menu(byId[id]!),
      onMoved: (id, p) async {
        await (await _dao()).moveNode(id, p.dx, p.dy);
        _refresh();
      },
      // Only the comic shapes take a size on the desktop (dgComicDecorate).
      resizable: (id) => const {'panel', 'balloon'}.contains(byId[id]!.shape),
      onResized: (id, s) async {
        await (await _dao()).resizeNode(id, s.width, s.height);
        _refresh();
      },
    );
  }

  /// Each node with where it leads (EXE buildDesignerOutlineHtml).
  Widget _outline(List<DesignNodeModel> nodes, List<DesignEdgeModel> edges) {
    final byId = {for (final n in nodes) n.id: n};
    final ordered = [...nodes]..sort((a, b) => (a.readOrder ?? 1 << 30).compareTo(b.readOrder ?? 1 << 30));
    return Column(children: [
      for (final n in ordered)
        ListTile(
          dense: true,
          leading: Text(n.readOrder != null ? '${n.readOrder}' : (_glyph[n.shape] ?? '▭')),
          title: Text(designNodeName(n)),
          subtitle: Text([
            for (final e in edges)
              if (e.fromRef == n.id) '→ ${e.label?.isNotEmpty == true ? '${e.label} → ' : ''}${designNodeName(byId[e.toRef] ?? n)}',
          ].join('\n').ifEmpty('—')),
          onTap: () => _edit(n),
          onLongPress: () => _menu(n),
        ),
    ]);
  }

  /// Who links to whom, as a grid (EXE buildDesignerMatrixHtml).
  Widget _matrix(List<DesignNodeModel> nodes, List<DesignEdgeModel> edges) {
    final theme = Theme.of(context);
    final label = {for (final e in edges) '${e.fromRef}-${e.toRef}': e.label?.isNotEmpty == true ? e.label! : '·'};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DataTable(
        columnSpacing: 12,
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 40,
        columns: [
          const DataColumn(label: SizedBox.shrink()),
          for (final n in nodes) DataColumn(label: Text(designNodeName(n), style: theme.textTheme.labelSmall)),
        ],
        rows: [
          for (final a in nodes)
            DataRow(cells: [
              DataCell(Text(designNodeName(a), style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold))),
              for (final b in nodes)
                DataCell(
                  Container(
                    color: label.containsKey('${a.id}-${b.id}') && a.id != b.id ? theme.colorScheme.primaryContainer : null,
                    padding: const EdgeInsets.all(4),
                    child: Text(a.id == b.id ? '' : (label['${a.id}-${b.id}'] ?? '')),
                  ),
                ),
            ]),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
