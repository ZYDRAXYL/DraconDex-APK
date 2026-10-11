import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/core/theme/app_theme.dart';
import 'package:dracondex/core/theme/ddx_theme.dart';
import 'package:dracondex/core/theme/tokens.g.dart' hide DdxGlass;
import 'package:dracondex/widgets/ddx_card.dart';
import 'package:dracondex/widgets/ddx_chip.dart';
import 'package:dracondex/widgets/ddx_field.dart';
import 'package:dracondex/widgets/ddx_glass.dart';
import 'package:dracondex/widgets/ddx_icon_button.dart';
import 'package:dracondex/widgets/ddx_popover.dart';
import 'package:dracondex/widgets/ddx_segmented.dart';

/// The shared widgets of APP Plan.md Procress 22 part 3 (APK half) — the
/// registry's popover, chip, segmented, card, icon button and field.
void main() {
  Widget app(Widget child, {String theme = 'midnight', TargetPlatform? platform}) => MaterialApp(
        theme: AppTheme.forName(theme).copyWith(platform: platform),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  void tablet(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('DdxChip', () {
    testWidgets('every kind renders its label', (tester) async {
      var on = false;
      await tester.pumpWidget(app(Wrap(children: [
        const DdxChip.tag('hero', color: Color(0xFFFF0000)),
        StatefulBuilder(
          builder: (_, set) => DdxChip.filter('Open', selected: on, onSelected: (v) => set(() => on = v)),
        ),
        const DdxChip.status('Draft', tone: DdxTone.warn),
        const DdxChip.status('Done', tone: DdxTone.success),
        const DdxChip.count('Scenes', 7),
        const DdxChip.tag('small', size: DdxChipSize.sm),
      ])));
      expect(find.text('#hero'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Scenes'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(on, isTrue);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('a tag\'s own colour is the dot, never the label', (tester) async {
      const user = Color(0xFF00FF00);
      await tester.pumpWidget(app(const DdxChip.tag('hero', color: user)));
      final label = tester.widget<Text>(find.text('#hero'));
      expect(label.style!.color, ddxPalettes['midnight']!.t1);
      final dot = find.byWidgetPredicate(
          (w) => w is Container && w.decoration is BoxDecoration && (w.decoration! as BoxDecoration).color == user);
      expect(dot, findsOneWidget);
    });

    testWidgets('an interactive chip has a 48dp target and a selected state', (tester) async {
      await tester.pumpWidget(app(DdxChip.filter('Open', selected: true, onSelected: (_) {})));
      expect(tester.getSize(find.byType(DdxChip)).height, greaterThanOrEqualTo(48));
      final node = tester.getSemantics(find.byType(DdxChip));
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
    });

    // SDB's contrast survey (32 themes): the label pairs every chip may use.
    test('every chip label reaches 4.5:1 in every theme', () {
      final failures = <String>[];
      for (final name in ddxPalettes.keys) {
        final ddx = DdxThemeExt(name: name, palette: ddxPalettes[name]!);
        final cases = <String, (Color, Color)>{
          'tag': DdxChip.colorsFor(ddx, kind: DdxChipKind.tag),
          'filter': DdxChip.colorsFor(ddx, kind: DdxChipKind.filter),
          'filter selected': DdxChip.colorsFor(ddx, kind: DdxChipKind.filter, selected: true),
          'count': DdxChip.colorsFor(ddx, kind: DdxChipKind.count),
          for (final t in DdxTone.values) 'status ${t.name}': DdxChip.colorsFor(ddx, kind: DdxChipKind.status, tone: t),
        };
        cases.forEach((k, v) {
          final r = DdxThemeExt.contrast(v.$2, v.$1);
          if (r < 4.5) failures.add('$name $k ${r.toStringAsFixed(2)}');
        });
        // the count badge
        final p = ddx.palette;
        if (DdxThemeExt.contrast(p.t1, p.raised) < 4.5) failures.add('$name count badge');
        // DdxSegmented: unselected t1 on raised, selected on-accent on accent
        if (DdxThemeExt.contrast(ddx.onAccent, p.accent) < 4.5) failures.add('$name segment selected');
      }
      expect(failures, isEmpty);
    });
  });

  group('DdxSegmented', () {
    Widget seg(ValueChanged<String> on) => DdxSegmented<String>(
          segments: const [DdxSegment(value: 'a', label: 'Alpha'), DdxSegment(value: 'b', label: 'Beta')],
          selected: 'a',
          onChanged: on,
        );

    testWidgets('Material: a SegmentedButton', (tester) async {
      String? got;
      await tester.pumpWidget(app(seg((v) => got = v)));
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      await tester.tap(find.text('Beta'));
      expect(got, 'b');
    });

    testWidgets('iOS: a sliding segmented control', (tester) async {
      String? got;
      await tester.pumpWidget(app(seg((v) => got = v), platform: TargetPlatform.iOS));
      expect(find.byType(CupertinoSlidingSegmentedControl<String>), findsOneWidget);
      expect(find.byType(SegmentedButton<String>), findsNothing);
      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();
      expect(got, 'b');
    });
  });

  group('DdxCard', () {
    testWidgets('every kind renders; a link card is tappable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(app(Column(children: [
        const DdxCard(child: Text('info')),
        DdxCard(kind: DdxCardKind.link, onTap: () => taps++, child: const Text('link')),
        const DdxCard(kind: DdxCardKind.preview, child: SizedBox(height: 40, child: Text('preview'))),
      ])));
      for (final t in ['info', 'link', 'preview']) {
        expect(find.text(t), findsOneWidget);
      }
      await tester.tap(find.text('link'));
      expect(taps, 1);
    });
  });

  group('DdxIconButton', () {
    testWidgets('its tooltip is its accessible name; the target is 48dp at any size', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(Row(mainAxisSize: MainAxisSize.min, children: [
        DdxIconButton(icon: Icons.add, tooltip: 'Add scene', onPressed: () {}, size: DdxIconSize.sm),
        DdxIconButton(icon: Icons.edit, tooltip: 'Edit', onPressed: () {}),
      ])));
      expect(find.semantics.byPredicate((n) => n.getSemanticsData().tooltip == 'Add scene'), findsOneWidget);
      final s = tester.getSize(find.byType(DdxIconButton).first);
      expect(s.width, greaterThanOrEqualTo(48));
      expect(s.height, greaterThanOrEqualTo(48));
      handle.dispose();
    });
  });

  group('DdxField', () {
    testWidgets('an error is shown under the field and marks it invalid', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(const SizedBox(width: 300, child: DdxField(label: 'Name', errorText: 'Required'))));
      expect(find.text('Required'), findsOneWidget);
      expect(
        find.semantics.byPredicate((n) => n.getSemanticsData().validationResult == SemanticsValidationResult.invalid),
        findsOneWidget,
      );
      await tester.pumpWidget(app(const SizedBox(width: 300, child: DdxField(label: 'Name'))));
      expect(
        find.semantics.byPredicate((n) => n.getSemanticsData().validationResult == SemanticsValidationResult.invalid),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('disabled and read-only reach the TextField; height follows --ctl-*', (tester) async {
      await tester.pumpWidget(app(const SizedBox(
        width: 300,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DdxField(key: ValueKey('d'), hint: 'disabled', enabled: false),
          DdxField(key: ValueKey('r'), hint: 'readonly', readOnly: true),
          DdxField(key: ValueKey('sm'), hint: 'small', size: DdxFieldSize.sm),
        ]),
      )));
      TextField tf(String k) => tester.widget<TextField>(find.descendant(of: find.byKey(ValueKey(k)), matching: find.byType(TextField)));
      expect(tf('d').enabled, isFalse);
      expect(tf('r').readOnly, isTrue);
      expect(tester.getSize(find.byKey(const ValueKey('r'))).height, greaterThanOrEqualTo(DdxSize.ctlLg));
      expect(tester.getSize(find.byKey(const ValueKey('sm'))).height, lessThan(DdxSize.ctlLg));
    });
  });

  group('showDdxPopover', () {
    Widget opener({bool fromSheet = false}) => Builder(
          builder: (context) {
            void pop(BuildContext c) => showDdxPopover<String>(
                  context: c,
                  builder: (ctx) => ListTile(title: const Text('choice'), onTap: () => Navigator.pop(ctx, 'x')),
                );
            return TextButton(
              onPressed: () => fromSheet
                  ? showDdxSheet<void>(
                      context: context,
                      builder: (sheet) => Builder(
                        builder: (inner) => TextButton(onPressed: () => pop(inner), child: const Text('inner')),
                      ),
                    )
                  : pop(context),
              child: const Text('open'),
            );
          },
        );

    testWidgets('a sheet on a phone', (tester) async {
      phone(tester);
      await tester.pumpWidget(app(opener()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('choice'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('anchored beside its anchor on a wide screen', (tester) async {
      tablet(tester);
      await tester.pumpWidget(app(opener()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      final anchor = tester.getRect(find.text('open'));
      final pane = tester.getRect(find.text('choice'));
      expect(pane.top, greaterThan(anchor.bottom - 1));
      expect((pane.top - anchor.bottom).abs(), lessThan(60));
      // Esc closes it
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('choice'), findsNothing);
    });

    testWidgets('never a sheet over a sheet', (tester) async {
      phone(tester);
      await tester.pumpWidget(app(opener(fromSheet: true)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('inner'));
      await tester.pumpAndSettle();
      expect(find.text('choice'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.text('choice'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    test('the positioner flips above and stays on screen', () {
      const screen = Size(800, 600);
      const child = Size(200, 300);
      const low = DdxPopoverLayout(anchor: Rect.fromLTWH(700, 500, 80, 40), width: 200, maxHeight: 400);
      final at = low.getPositionForChild(screen, child);
      expect(at.dy + child.height, lessThanOrEqualTo(500));
      expect(at.dx + child.width, lessThanOrEqualTo(800 - 8));
    });
  });
}
