import 'package:flutter/material.dart';

import '../module_page.dart';

/// A box on a [NodeCanvas]: [pos] is its top-left in the canvas's own
/// coordinates (the desktop's pos_x/pos_y or x/y).
class CanvasNode {
  final int id;
  final Offset pos;
  final Size size;
  final Widget child;
  const CanvasNode(this.id, this.pos, this.size, this.child);
}

class CanvasLink {
  final int from;
  final int to;
  final String? label;
  const CanvasLink(this.from, this.to, {this.label});
}

/// A board of boxes joined by arrows — the phone's shared frame for the
/// Narrator board and the Designer canvas (APK-V3.md §4). On the page it is
/// the whole board fitted to the block; full screen it pans and pinches, and
/// a box drags to move ([onMoved] saves where it was dropped).
class NodeCanvas extends StatefulWidget {
  final List<CanvasNode> nodes;
  final List<CanvasLink> links;
  final bool fullScreen;
  final void Function(int id)? onTap;
  final void Function(int id)? onLongPress;
  final Future<void> Function(int id, Offset pos)? onMoved;

  /// Full screen only: the boxes this names get a corner grip, and the size
  /// they were dragged to is saved here (never below [minSize]).
  final bool Function(int id)? resizable;
  final Future<void> Function(int id, Size size)? onResized;
  final Size minSize;

  const NodeCanvas({
    super.key,
    required this.nodes,
    required this.links,
    required this.fullScreen,
    this.onTap,
    this.onLongPress,
    this.onMoved,
    this.resizable,
    this.onResized,
    this.minSize = const Size(40, 30),
  });

  @override
  State<NodeCanvas> createState() => _NodeCanvasState();
}

class _NodeCanvasState extends State<NodeCanvas> {
  final Map<int, Offset> _drag = {};
  final Map<int, Size> _resize = {};

  Offset _pos(CanvasNode n) => _drag[n.id] ?? n.pos;
  Size _size(CanvasNode n) => _resize[n.id] ?? n.size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var world = Rect.zero;
    var first = true;
    for (final n in widget.nodes) {
      final r = _pos(n) & _size(n);
      world = first ? r : world.expandToInclude(r);
      first = false;
    }
    world = world.inflate(60);
    final o = world.topLeft;
    final byId = {for (final n in widget.nodes) n.id: n};

    final canvas = SizedBox(
      width: world.width,
      height: world.height,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _LinkPainter([
              for (final l in widget.links)
                if (byId[l.from] != null && byId[l.to] != null)
                  (
                    (_pos(byId[l.from]!) - o) & _size(byId[l.from]!),
                    (_pos(byId[l.to]!) - o) & _size(byId[l.to]!),
                    l.label ?? '',
                  ),
            ], scheme),
          ),
        ),
        for (final n in widget.nodes)
          Positioned(
            left: _pos(n).dx - o.dx,
            top: _pos(n).dy - o.dy,
            width: _size(n).width,
            height: _size(n).height,
            child: GestureDetector(
              onTap: widget.onTap == null ? null : () => widget.onTap!(n.id),
              onLongPress: widget.onLongPress == null ? null : () => widget.onLongPress!(n.id),
              onPanUpdate: widget.onMoved == null ? null : (d) => setState(() => _drag[n.id] = _pos(n) + d.delta),
              onPanEnd: widget.onMoved == null
                  ? null
                  : (_) async {
                      final at = _drag[n.id];
                      if (at == null) return;
                      await widget.onMoved!(n.id, at);
                      if (mounted) setState(() => _drag.remove(n.id));
                    },
              child: n.child,
            ),
          ),
        if (widget.fullScreen && widget.onResized != null)
          for (final n in widget.nodes)
            if (widget.resizable?.call(n.id) ?? true)
              Positioned(
                left: _pos(n).dx - o.dx + _size(n).width - ResizeGrip.size / 2,
                top: _pos(n).dy - o.dy + _size(n).height - ResizeGrip.size / 2,
                child: ResizeGrip(
                  onDrag: (d) => setState(() {
                    final s = _size(n);
                    _resize[n.id] = Size(
                        (s.width + d.dx).clamp(widget.minSize.width, 4000), (s.height + d.dy).clamp(widget.minSize.height, 4000));
                  }),
                  onEnd: () async {
                    final s = _resize[n.id];
                    if (s == null) return;
                    await widget.onResized!(n.id, s);
                    if (mounted) setState(() => _resize.remove(n.id));
                  },
                ),
              ),
      ]),
    );
    if (widget.fullScreen) {
      return InteractiveViewer(
        constrained: false,
        minScale: 0.2,
        maxScale: 3,
        boundaryMargin: const EdgeInsets.all(400),
        child: canvas,
      );
    }
    return SizedBox(height: CanvasFrame.thumbHeight + 80, child: FittedBox(child: canvas));
  }
}

class _LinkPainter extends CustomPainter {
  final List<(Rect, Rect, String)> lines;
  final ColorScheme scheme;
  _LinkPainter(this.lines, this.scheme);

  /// Where the line from [c] toward [to] leaves the box [r].
  Offset _edge(Rect r, Offset to) {
    final c = r.center;
    final d = to - c;
    if (d.dx == 0 && d.dy == 0) return c;
    final sx = d.dx == 0 ? double.infinity : (r.width / 2) / d.dx.abs();
    final sy = d.dy == 0 ? double.infinity : (r.height / 2) / d.dy.abs();
    final s = sx < sy ? sx : sy;
    return c + d * (s > 1 ? 1 : s);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = scheme.outline
      ..strokeWidth = 1.5;
    for (final (a, b, label) in lines) {
      final s = _edge(a, b.center), e = _edge(b, a.center);
      canvas.drawLine(s, e, p);
      final dir = (e - s).distance == 0 ? Offset.zero : (e - s) / (e - s).distance;
      final side = Offset(-dir.dy, dir.dx) * 5;
      canvas.drawPath(
          Path()
            ..moveTo(e.dx, e.dy)
            ..lineTo(e.dx - dir.dx * 10 + side.dx, e.dy - dir.dy * 10 + side.dy)
            ..lineTo(e.dx - dir.dx * 10 - side.dx, e.dy - dir.dy * 10 - side.dy)
            ..close(),
          Paint()..color = scheme.outline);
      if (label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, backgroundColor: scheme.surface)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 160);
        tp.paint(canvas, (s + e) / 2 - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_LinkPainter old) => true;
}

/// The corner handle a box resizes by (EXE .dg-resize): a finger-sized hit
/// area around a small visible mark, so it wins over the board's pan.
class ResizeGrip extends StatelessWidget {
  static const size = 28.0;
  final void Function(Offset delta) onDrag;
  final Future<void> Function() onEnd;
  const ResizeGrip({super.key, required this.onDrag, required this.onEnd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (d) => onDrag(d.delta),
      onPanEnd: (_) => onEnd(),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: scheme.primary,
              border: Border.all(color: scheme.surface, width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}
