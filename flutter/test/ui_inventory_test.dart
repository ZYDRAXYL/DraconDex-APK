import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The ratchet of APP Plan.md Procress 22 part 4 (APK side): how many raw
/// Material widgets are still used in lib/ outside the shared `ddx_*`
/// widgets. Each count may only go down. A new screen uses DdxChip,
/// DdxSegmented, DdxCard, DdxIconButton, DdxField, showDdxPopover /
/// showDdxSheet / showDdxDialog (APP docs/COMPONENTS.md) — and when a
/// migration lowers a count, lower its baseline here in the same change.
///
/// What is left on purpose (2026-10-12):
///  * ActionChip — buttons and links that happen to be pill-shaped
///    (a relation, a backlink, "+ new table"), not one of the four chips;
///  * Card — the Diviner's last-roll highlight on primaryContainer;
///  * IconButton — toggles with a state-dependent icon, compact density
///    rows, an icon that is a ColorDot, a white arrow on a cover image;
///  * TextField — borderless inline editors and search bars;
///  * showModalBottomSheet — the colour picker's DraggableScrollableSheet,
///    which draws its own glass.
void main() {
  const baseline = <String, int>{
    'Chip(': 0,
    'FilterChip(': 0,
    'ChoiceChip(': 0,
    'InputChip(': 0,
    'ActionChip(': 9,
    'SegmentedButton<': 0,
    'showModalBottomSheet': 1,
    'showDialog': 0,
    'Card(': 1,
    'IconButton(': 13,
    'TextField(': 19,
  };

  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.uri.pathSegments.last.startsWith('ddx_'))
      .toList();
  final sources = {for (final f in files) f.path: f.readAsStringSync()};

  for (final MapEntry(key: name, value: max) in baseline.entries) {
    test('raw $name uses ≤ $max', () {
      // not preceded by a letter, digit, _ or . — `DdxChip(` and
      // `foo.Card(` are not `Chip(`/`Card(`
      final re = RegExp(r'(?<![\w.])' + RegExp.escape(name) + (name.endsWith('(') || name.endsWith('<') ? '' : r'[<(]'));
      final hits = <String>[];
      sources.forEach((path, src) {
        for (final m in re.allMatches(src)) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          final text = src.substring(src.lastIndexOf('\n', m.start) + 1, m.start).trimLeft();
          if (text.startsWith('//')) continue;
          hits.add('$path:$line');
        }
      });
      expect(hits.length, lessThanOrEqualTo(max),
          reason: 'new raw $name — use the shared ddx_* widget instead:\n${hits.join('\n')}');
    });
  }
}
