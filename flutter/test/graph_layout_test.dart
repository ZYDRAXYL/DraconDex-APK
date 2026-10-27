import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dracondex/core/icon_refs.dart';
import 'package:dracondex/features/page/views/graph_view.dart';

/// Procress 28 part 3 — the relation view's layout: nodes nothing pulls on
/// sit on the outer band (inside the box at any count, out of the force
/// pass), the linked ones in the middle.
void main() {
  const size = Size(360, 300);
  bool inside(Offset p) => p.dx >= 0 && p.dx <= size.width && p.dy >= 0 && p.dy <= size.height;

  test('3,000 unlinked nodes are placed inside the box, quickly, around the linked few', () {
    final nodes = [
      const GraphNode('a', 'A'),
      const GraphNode('b', 'B'),
      for (var i = 0; i < 3000; i++) GraphNode('o$i', 'O$i', outer: true),
    ];
    final sw = Stopwatch()..start();
    final pos = layoutGraph(nodes, const [GraphEdge('a', 'b')], size);
    sw.stop();
    expect(pos.length, nodes.length);
    expect(pos.values.every(inside), isTrue);
    expect(sw.elapsedMilliseconds, lessThan(500), reason: 'the force pass runs over two nodes, not 3,002');
    final c = Offset(size.width / 2, size.height / 2);
    final rLinked = (pos['a']! - c).distance;
    final rOuterMin = [for (var i = 0; i < 3000; i++) (pos['o$i']! - c).distance].reduce((x, y) => x < y ? x : y);
    expect(rOuterMin, greaterThan(rLinked * 0.5), reason: 'the band stays out of the middle');
  });

  test('icon refs: a catalogue name is an icon, a symbol a glyph, the rest nothing', () {
    expect(iconForRef('svg:star'), Icons.star_outline);
    expect(iconForRef('person'), Icons.person_outline);
    expect(iconForRef('svg:nope'), isNull);
    expect(iconForRef('sym:🐉'), isNull);
    expect(glyphForRef('sym:🐉'), '🐉');
    expect(glyphForRef('svg:star'), isNull);
    expect(iconForRef(null), isNull);
  });
}
