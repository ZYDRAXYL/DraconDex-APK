import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dracondex/core/icon_sets.dart';
import 'package:dracondex/widgets/ddx_ref_icon.dart';

/// Procress 29 part 7: an icon chosen on the desktop draws here too.
void main() {
  Future<void> pump(WidgetTester t, String? ref) =>
      t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: DdxRefIcon(ref, size: 24, fallback: Icons.folder)))));

  testWidgets('every kind of reference draws as itself; anything else is the fallback', (t) async {
    IconSets.add('lucide', File('assets/icon-sets/lucide.json').readAsStringSync());
    await pump(t, 'svg:lucide/castle');
    expect(find.byType(SvgPicture), findsOneWidget);
    await pump(t, 'svg:star');
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
    await pump(t, 'sym:龍');
    expect(find.text('龍'), findsOneWidget);
    await pump(t, 'img:data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==');
    expect(find.byType(Image), findsOneWidget);
    for (final r in [null, '', 'svg:nope', 'img:http://x/y.png']) {
      await pump(t, r);
      expect(find.byIcon(Icons.folder), findsOneWidget, reason: '$r');
    }
    await pump(t, 'svg:lucide/no-such-icon-x');
    expect(find.byType(SvgPicture), findsNothing, reason: 'a name the set does not have draws nothing');
  });

  test('the three sets are shipped, with their licences, and readable', () {
    for (final id in IconSets.ids) {
      expect(File('assets/icon-sets/LICENSE-$id').existsSync(), isTrue, reason: id);
      IconSets.add(id, File('assets/icon-sets/$id.json').readAsStringSync());
      expect(IconSets.loaded(id)!.icons.length, greaterThan(1000), reason: id);
    }
    expect(IconSets.loaded('tabler')!.svg('home'), contains('viewBox="0 0 24 24"'));
    expect(IconSets.isSetRef('lucide/castle'), isTrue);
    expect(IconSets.isSetRef('star'), isFalse);
    expect(DdxRefIcon.draws('svg:phosphor/house'), isTrue);
    expect(DdxRefIcon.draws('svg:nope'), isFalse);
  });
}
