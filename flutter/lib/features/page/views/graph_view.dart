import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A node of [GraphView].
class GraphNode {
  final String key;
  final String label;
  final Color? color;

  /// Procress 28 part 3: drawn instead of the dot, in [color] — an element's
  /// own icon ([icon]) or symbol ([glyph]).
  final IconData? icon;
  final String? glyph;

  /// Nothing pulls on it (no edge): it sits on rings round the graph,
  /// outside the force pass — 3,000 of them cost a placement, not 3,000².
  final bool outer;
  const GraphNode(this.key, this.label, {this.color, this.icon, this.glyph, this.outer = false});
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

  /// A long press on a node — the phone's hover (Procress 28 part 3).
  final void Function(GraphNode node)? onLongPress;
  final bool fullScreen;
  final double height;

  const GraphView({
    super.key,
    required this.nodes,
    required this.edges,
    this.onTap,
    this.onLongPress,
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
      GraphNode? at(Offset o) {
        for (final n in nodes.reversed) {
          final p = pos[n.key];
          if (p != null && (p - o).distance <= 18) return n;
        }
        return null;
      }

      Widget canvas = GestureDetector(
        onTapUp: (d) {
          if (at(d.localPosition) case final n?) onTap?.call(n);
        },
        onLongPressStart: onLongPress == null
            ? null
            : (d) {
                if (at(d.localPosition) case final n?) onLongPress!(n);
              },
        child: ClipRect(child: CustomPaint(size: Size(w, h), painter: painter)),
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
Map<String, Offset> layoutGraph(List<GraphNode> all, List<GraphEdge> edges, Size size) {
  final c = Offset(size.width / 2, size.height / 2);
  // The outer nodes fill a band round the middle as a sunflower spiral — even
  // at any count and always inside the box (a phone's graph does not pan);
  // the rest go through the force pass.
  final ring = <String, Offset>{};
  {
    final outer = [for (final nd in all) if (nd.outer) nd];
    final rMax = math.min(size.width, size.height) / 2 - 12, r0 = rMax * 0.62;
    for (var i = 0; i < outer.length; i++) {
      final r = math.sqrt(r0 * r0 + (rMax * rMax - r0 * r0) * (i + 0.5) / outer.length);
      final a = i * 2.399963; // the golden angle
      ring[outer[i].key] = c + Offset(math.cos(a) * r * size.width / math.min(size.width, size.height), math.sin(a) * r);
    }
  }
  final nodes = [for (final nd in all) if (!nd.outer) nd];
  final n = nodes.length;
  if (n == 0) return ring;
  if (n == 1) return {...ring, nodes.first.key: c};
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
  return {...ring, ...pos};
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
      final col = nd.color ?? scheme.primary;
      if (nd.icon != null || nd.glyph != null) {
        canvas.drawCircle(p, 11, Paint()..color = scheme.surface);
        canvas.drawCircle(
            p,
            11,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = col
              ..strokeWidth = 1.5);
        final s = nd.icon != null ? String.fromCharCode(nd.icon!.codePoint) : nd.glyph!;
        _text(canvas, s, p,
            TextStyle(fontSize: 13, color: col, fontFamily: nd.icon?.fontFamily, package: nd.icon?.fontPackage, height: 1));
      } else {
        canvas.drawCircle(p, nd.outer ? 7 : 10, Paint()..color = col);
        canvas.drawCircle(
            p,
            nd.outer ? 7 : 10,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = scheme.surface
              ..strokeWidth = 2);
      }
      if (nd.outer) continue; // a ring of 3,000 names is noise — a long press says which
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
