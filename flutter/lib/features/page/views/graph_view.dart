import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A node of [GraphView].
class GraphNode {
  final String key;
  final String label;
  final Color? color;
  const GraphNode(this.key, this.label, {this.color});
}

/// An edge of [GraphView]; [from]/[to] are node keys.
class GraphEdge {
  final String from;
  final String to;
  final String? label;
  final bool directed;
  const GraphEdge(this.from, this.to, {this.label, this.directed = true});
}

/// A small node-link graph, the phone's stand-in for the desktop's D3 graph
/// (EXE sage.js buildSageGraph): laid out once by a deterministic force pass,
/// so the same data always lands the same way, then drawn with one painter.
/// A tap on a node calls [onTap]. In full screen it pans and pinch-zooms.
class GraphView extends StatelessWidget {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final void Function(GraphNode node)? onTap;
  final bool fullScreen;
  final double height;

  const GraphView({
    super.key,
    required this.nodes,
    required this.edges,
    this.onTap,
    this.fullScreen = false,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 360.0;
      final h = fullScreen && box.maxHeight.isFinite ? box.maxHeight : height;
      final pos = layoutGraph(nodes, edges, Size(w, h));
      final painter = _GraphPainter(nodes, edges, pos, scheme, Theme.of(context).textTheme.labelSmall!);
      Widget canvas = GestureDetector(
        onTapUp: (d) {
          for (final n in nodes.reversed) {
            final p = pos[n.key];
            if (p != null && (p - d.localPosition).distance <= 18) {
              onTap?.call(n);
              return;
            }
          }
        },
        child: CustomPaint(size: Size(w, h), painter: painter),
      );
      if (fullScreen) {
        canvas = InteractiveViewer(minScale: 0.4, maxScale: 4, boundaryMargin: const EdgeInsets.all(200), child: canvas);
      }
      return SizedBox(width: w, height: h, child: canvas);
    });
  }
}

/// Node positions: a circle start, then a fixed number of force steps
/// (repulsion between all pairs, springs along edges, a pull to the middle).
Map<String, Offset> layoutGraph(List<GraphNode> nodes, List<GraphEdge> edges, Size size) {
  final n = nodes.length;
  final c = Offset(size.width / 2, size.height / 2);
  if (n == 0) return {};
  if (n == 1) return {nodes.first.key: c};
  final r = math.min(size.width, size.height) * 0.38;
  final pos = <String, Offset>{
    for (var i = 0; i < n; i++) nodes[i].key: c + Offset(math.cos(2 * math.pi * i / n), math.sin(2 * math.pi * i / n)) * r,
  };
  final k = math.sqrt(size.width * size.height / n) * 0.6;
  final links = [for (final e in edges) if (pos.containsKey(e.from) && pos.containsKey(e.to) && e.from != e.to) e];
  var temp = size.width / 8;
  for (var it = 0; it < 120; it++) {
    final disp = {for (final nd in nodes) nd.key: Offset.zero};
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final a = nodes[i].key, b = nodes[j].key;
        var d = pos[a]! - pos[b]!;
        var dist = d.distance;
        if (dist < 0.01) {
          d = Offset(1.0 + i, 1.0 + j);
          dist = d.distance;
        }
        final f = d / dist * (k * k / dist);
        disp[a] = disp[a]! + f;
        disp[b] = disp[b]! - f;
      }
    }
    for (final e in links) {
      final d = pos[e.from]! - pos[e.to]!;
      final dist = math.max(d.distance, 0.01);
      final f = d / dist * (dist * dist / k);
      disp[e.from] = disp[e.from]! - f;
      disp[e.to] = disp[e.to]! + f;
    }
    for (final nd in nodes) {
      var d = disp[nd.key]! + (c - pos[nd.key]!) * 0.05;
      final len = d.distance;
      if (len > temp) d = d / len * temp;
      final p = pos[nd.key]! + d;
      pos[nd.key] = Offset(p.dx.clamp(24, size.width - 24), p.dy.clamp(20, size.height - 20));
    }
    temp *= 0.96;
  }
  return pos;
}

class _GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Map<String, Offset> pos;
  final ColorScheme scheme;
  final TextStyle label;
  _GraphPainter(this.nodes, this.edges, this.pos, this.scheme, this.label);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = scheme.outline
      ..strokeWidth = 1.2;
    for (final e in edges) {
      final a = pos[e.from], b = pos[e.to];
      if (a == null || b == null) continue;
      canvas.drawLine(a, b, line);
      if (e.directed && a != b) {
        final dir = (b - a) / (b - a).distance;
        final tip = b - dir * 14;
        final side = Offset(-dir.dy, dir.dx) * 4;
        canvas.drawPath(
            Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo(tip.dx - dir.dx * 8 + side.dx, tip.dy - dir.dy * 8 + side.dy)
              ..lineTo(tip.dx - dir.dx * 8 - side.dx, tip.dy - dir.dy * 8 - side.dy)
              ..close(),
            Paint()..color = scheme.outline);
      }
      if (e.label != null && e.label!.isNotEmpty) {
        _text(canvas, e.label!, (a + b) / 2, label.copyWith(color: scheme.onSurfaceVariant, fontSize: 10));
      }
    }
    for (final nd in nodes) {
      final p = pos[nd.key];
      if (p == null) continue;
      canvas.drawCircle(p, 10, Paint()..color = nd.color ?? scheme.primary);
      canvas.drawCircle(
          p,
          10,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = scheme.surface
            ..strokeWidth = 2);
      _text(canvas, nd.label, p + const Offset(0, 18), label.copyWith(color: scheme.onSurface));
    }
  }

  void _text(Canvas canvas, String s, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: s.length > 24 ? '${s.substring(0, 23)}…' : s, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 140);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_GraphPainter old) => old.nodes != nodes || old.edges != edges || old.pos != pos || old.scheme != scheme;
}

/// A hex colour code (#rrggbb) as a Color, or null.
Color? hexColor(String? code) {
  if (code == null) return null;
  final h = code.replaceFirst('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}
