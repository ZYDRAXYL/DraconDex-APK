import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/models/designer_model.dart';
import '../../../providers/db_providers.dart';
import '../../../providers/module_content_provider.dart';

/// Designer kind: a free-form diagram board.
///
/// This is the first kind that genuinely needs a canvas. Narrator's positions
/// belong to the desktop and are left alone; a Designer's coordinates are its
/// content, so they are read and written here.
///
/// The board is a fixed logical area inside an InteractiveViewer, which gives
/// pan and zoom without inventing a coordinate system the desktop would not
/// recognise — a node at (400, 300) sits at (400, 300) on both front-ends.
/// Edges are painted under the nodes by [_EdgePainter]; the nodes themselves
/// are ordinary widgets so they stay accessible and hit-testable.
class DesignerContent extends ConsumerStatefulWidget {
  final int moduleId;
  const DesignerContent({super.key, required this.moduleId});

  @override
  ConsumerState<DesignerContent> createState() => _DesignerContentState();
}

class _DesignerContentState extends ConsumerState<DesignerContent> {
  /// The logical board. Big enough to lay a diagram out in, small enough that
  /// InteractiveViewer's fit-to-screen is not absurd.
  static const double _boardW = 2000;
  static const double _boardH = 1400;
  static const double _nodeW = 132;
  static const double _nodeH = 56;

  /// When set, the next node tapped becomes the destination of a new edge.
  int? _linkFrom;

  /// Drag positions held locally so the node follows the finger without a
  /// database write per frame; committed on drag end.
  final Map<int, Offset> _dragging = {};

  Future<void> _addNode() async {
    final dao = ref.read(designerDaoProvider).valueOrNull;
    if (dao == null) return;
    final l10n = AppLocalizations.of(context)!;
    // Placed near the top-left of the board rather than at a guessed centre,
    // so a new node is always somewhere the user can find it.
    await dao.createNode(
      moduleRef: widget.moduleId,
      x: 60,
      y: 60,
      text: l10n.designerNewNode,
    );
    ref.invalidate(designNodesProvider(widget.moduleId));
  }

  Future<void> _editNode(DesignNodeModel n) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: n.text ?? '');
    var shape = n.shape;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(l10n.designerNode),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.designerNodeText),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final s in const ['box', 'ellipse', 'diamond'])
                    ChoiceChip(
                      label: Text(s),
                      selected: shape == s,
                      onSelected: (_) => setLocal(() => shape = s),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('delete'),
              child: Text(l10n.btnDelete),
            ),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.btnCancel)),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop('save'), child: Text(l10n.btnSave)),
          ],
        ),
      ),
    );
    if (action == null) return;
    final dao = ref.read(designerDaoProvider).valueOrNull;
    if (dao == null) return;
    if (action == 'delete') {
      await dao.deleteNode(n.id);
      ref.invalidate(designEdgesProvider(widget.moduleId));
    } else {
      await dao.updateNode(n.id, text: controller.text.trim(), shape: shape);
    }
    ref.invalidate(designNodesProvider(widget.moduleId));
  }

  Future<void> _tapNode(DesignNodeModel n) async {
    if (_linkFrom == null) {
      await _editNode(n);
      return;
    }
    final from = _linkFrom!;
    setState(() => _linkFrom = null);
    if (from == n.id) return; // a node does not connect to itself
    final dao = ref.read(designerDaoProvider).valueOrNull;
    await dao?.addEdge(moduleRef: widget.moduleId, fromRef: from, toRef: n.id);
    ref.invalidate(designEdgesProvider(widget.moduleId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final nodesAsync = ref.watch(designNodesProvider(widget.moduleId));
    final edgesAsync = ref.watch(designEdgesProvider(widget.moduleId));

    if (nodesAsync.isLoading || edgesAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = nodesAsync.error ?? edgesAsync.error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$error', style: TextStyle(color: theme.colorScheme.error)),
      );
    }

    final nodes = nodesAsync.valueOrNull ?? const <DesignNodeModel>[];
    final edges = edgesAsync.valueOrNull ?? const <DesignEdgeModel>[];
    final centres = {
      for (final n in nodes)
        n.id: (_dragging[n.id] ?? Offset(n.x, n.y)) +
            const Offset(_nodeW / 2, _nodeH / 2),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Text(l10n.designerBoard, style: theme.textTheme.titleSmall),
              const Spacer(),
              if (_linkFrom != null)
                TextButton.icon(
                  onPressed: () => setState(() => _linkFrom = null),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(l10n.designerLinkCancel),
                ),
              TextButton.icon(
                onPressed: _addNode,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.designerNewNode),
              ),
            ],
          ),
        ),
        if (_linkFrom != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.designerLinkHint,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
        if (nodes.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(l10n.designerEmpty, style: theme.textTheme.bodySmall),
          )
        else
          SizedBox(
            height: 380,
            child: InteractiveViewer(
              constrained: false,
              minScale: 0.25,
              maxScale: 2.5,
              boundaryMargin: const EdgeInsets.all(80),
              child: SizedBox(
                width: _boardW,
                height: _boardH,
                child: Stack(
                  children: [
                    // Edges first so nodes sit on top of the lines.
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _EdgePainter(
                          edges: edges,
                          centres: centres,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    for (final n in nodes)
                      _NodeBox(
                        key: ValueKey(n.id),
                        node: n,
                        width: _nodeW,
                        height: _nodeH,
                        offset: _dragging[n.id] ?? Offset(n.x, n.y),
                        selected: _linkFrom == n.id,
                        onTap: () => _tapNode(n),
                        onLongPress: () => setState(() => _linkFrom = n.id),
                        onDragUpdate: (o) => setState(() => _dragging[n.id] = o),
                        onDragEnd: (o) async {
                          final dao = ref.read(designerDaoProvider).valueOrNull;
                          await dao?.moveNode(n.id, o.dx, o.dy);
                          if (!mounted) return;
                          setState(() => _dragging.remove(n.id));
                          ref.invalidate(designNodesProvider(widget.moduleId));
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NodeBox extends StatelessWidget {
  final DesignNodeModel node;
  final double width;
  final double height;
  final Offset offset;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<Offset> onDragEnd;

  const _NodeBox({
    super.key,
    required this.node,
    required this.width,
    required this.height,
    required this.offset,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // An unknown shape falls back to a box rather than failing to render:
    // design_node.shape has no CHECK upstream precisely so new shapes can
    // appear without a migration.
    final radius = switch (node.shape) {
      'ellipse' => BorderRadius.circular(height / 2),
      _ => BorderRadius.circular(6),
    };
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        onPanUpdate: (d) => onDragUpdate(offset + d.delta),
        onPanEnd: (_) => onDragEnd(offset),
        child: Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.dividerColor,
              width: selected ? 2 : 1,
            ),
            borderRadius: radius,
          ),
          child: Text(
            node.text ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  final List<DesignEdgeModel> edges;
  final Map<int, Offset> centres;
  final Color color;

  const _EdgePainter({required this.edges, required this.centres, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final e in edges) {
      final a = centres[e.fromRef];
      final b = centres[e.toRef];
      // An edge whose endpoint is missing is skipped rather than drawn to
      // the origin, which is what a stale cache would otherwise look like.
      if (a == null || b == null) continue;
      canvas.drawLine(a, b, paint);
    }
  }

  // `covariant` is stated explicitly rather than inherited from
  // CustomPainter's own declaration: narrowing the parameter type is only
  // legal because of it, and this is the repo's first CustomPainter, so
  // there is no local precedent to read it off.
  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.edges != edges || old.centres != centres || old.color != color;
}
