import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/core/theme/app_theme.dart';
import 'package:dracondex/core/theme/tokens.g.dart';
import 'package:dracondex/widgets/ddx_list.dart';
import 'package:dracondex/widgets/grouped_section.dart';
import 'package:dracondex/widgets/row_menu.dart';

/// Procress 21 (APP docs/UX-LAYOUT.md §12): the one list — two row heights
/// from the SDB tokens, groups with a count that fold, the header's sort,
/// and an empty state with room for one button only.
void main() {
  Widget app(Widget body, {bool ios = false, double textScale = 1}) {
    final theme = AppTheme.forName('midnight');
    return MaterialApp(
      theme: ios ? theme.copyWith(platform: TargetPlatform.iOS) : theme,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(body: body),
    );
  }

  double heightOf(WidgetTester tester, String title) =>
      tester.getSize(find.ancestor(of: find.text(title), matching: find.byType(ListTile))).height;

  group('DdxListTile', () {
    testWidgets('compact is rowCompact, comfortable is rowComfy — with meta, count and ⋯ too', (tester) async {
      List<RowAction> actions() => [RowAction(label: 'Rename', icon: Icons.edit, onTap: () {})];
      await tester.pumpWidget(app(ListView(children: [
        const DdxListTile(title: 'c', icon: Icons.folder, density: DdxDensity.compact),
        DdxListTile(title: 'c+', icon: Icons.folder, meta: 'right', count: '3', actions: actions, density: DdxDensity.compact),
        const DdxListTile(title: 'w', icon: Icons.folder),
        DdxListTile(title: 'w+', icon: Icons.folder, meta: 'second line', count: '12', actions: actions),
      ])));
      expect(heightOf(tester, 'c'), DdxSize.rowCompact);
      expect(heightOf(tester, 'c+'), DdxSize.rowCompact);
      expect(heightOf(tester, 'w'), DdxSize.rowComfy);
      expect(heightOf(tester, 'w+'), DdxSize.rowComfy);
      // compact: meta at the end of the row; comfortable: under the title
      expect(tester.getTopLeft(find.text('right')).dx, greaterThan(tester.getTopLeft(find.text('c+')).dx));
      expect(tester.getTopLeft(find.text('second line')).dy, greaterThan(tester.getTopLeft(find.text('w+')).dy));
      expect(find.byType(RowMenuButton), findsNWidgets(2), reason: 'the ⋯ is always shown');
    });

    testWidgets('both heights follow the text scale, still in proportion', (tester) async {
      await tester.pumpWidget(app(ListView(children: const [
        DdxListTile(title: 'c', density: DdxDensity.compact),
        DdxListTile(title: 'w'),
      ]), textScale: 1.5));
      expect(heightOf(tester, 'c'), DdxSize.rowCompact * 1.5);
      expect(heightOf(tester, 'w'), DdxSize.rowComfy * 1.5);
    });

    testWidgets('a long press opens the row menu; tap still taps', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(app(ListView(children: [
        DdxListTile(
          title: 'row',
          onTap: () => tapped++,
          actions: () => [RowAction(label: 'Rename', icon: Icons.edit, onTap: () {})],
        ),
      ])));
      await tester.tap(find.text('row'));
      expect(tapped, 1);
      await tester.longPress(find.text('row'));
      await tester.pumpAndSettle();
      expect(find.text('Rename'), findsOneWidget);
    });

    testWidgets('selected draws the start bar, not colour alone', (tester) async {
      await tester.pumpWidget(app(ListView(children: const [DdxListTile(title: 'on', selected: true), DdxListTile(title: 'off')])));
      final bars = find.byWidgetPredicate((w) =>
          w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).border is BorderDirectional);
      expect(bars, findsOneWidget);
      expect(find.ancestor(of: find.text('on'), matching: bars), findsOneWidget);
    });
  });

  group('DdxListSection', () {
    for (final ios in [false, true]) {
      testWidgets('shows its count and folds on a tap${ios ? ' (iOS)' : ''}', (tester) async {
        await tester.pumpWidget(app(ListView(children: [
          DdxListSection(title: 'Today', count: 2, children: const [DdxListTile(title: 'a'), DdxListTile(title: 'b')]),
        ]), ios: ios));
        expect(find.text('2'), findsOneWidget);
        expect(find.text('a'), findsOneWidget);
        if (ios) expect(find.byType(DdxGroupedSection), findsOneWidget, reason: 'the grouped inset card');
        await tester.tap(find.text(ios ? 'TODAY' : 'Today'));
        await tester.pump();
        expect(find.text('a'), findsNothing);
        expect(find.text('2'), findsOneWidget, reason: 'a folded group still says how many');
        await tester.tap(find.text(ios ? 'TODAY' : 'Today'));
        await tester.pump();
        expect(find.text('b'), findsOneWidget);
      });

      testWidgets('as a sliver builds only what shows, and folds${ios ? ' (iOS)' : ''}', (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 820));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(app(CustomScrollView(slivers: [
          DdxListSection.sliver(
            title: 'Older',
            count: 3000,
            itemCount: 3000,
            itemBuilder: (_, i) => DdxListTile(title: 'R$i'),
          ),
        ]), ios: ios));
        expect(find.text('3000'), findsOneWidget);
        expect(find.text('R0'), findsOneWidget);
        expect(find.text('R2999'), findsNothing);
        expect(find.textContaining(RegExp(r'^R\d+$')).evaluate().length, lessThan(40));
        await tester.tap(find.text(ios ? 'OLDER' : 'Older'));
        await tester.pump();
        expect(find.text('R0'), findsNothing);
      });
    }

    testWidgets('a section that does not fold has no chevron and ignores taps', (tester) async {
      await tester.pumpWidget(app(ListView(children: const [
        DdxListSection(title: 'About', collapsible: false, children: [DdxListTile(title: 'v1')]),
      ])));
      expect(find.byIcon(Icons.expand_more), findsNothing);
      await tester.tap(find.text('About'));
      await tester.pump();
      expect(find.text('v1'), findsOneWidget);
    });
  });

  group('DdxListHeader', () {
    testWidgets('sort menu reports the pick; filter reports typing; count shows', (tester) async {
      DdxSort? picked = DdxSort.created;
      var reported = false;
      var filter = '';
      await tester.pumpWidget(app(StatefulBuilder(
        builder: (context, setState) => DdxListHeader(
          count: 42,
          sort: picked,
          sorts: DdxSort.values,
          manualOrder: true,
          onSortChanged: (s) => setState(() {
            picked = s;
            reported = true;
          }),
          onFilterChanged: (v) => filter = v,
        ),
      )));
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ddx-list-sort')));
      await tester.pumpAndSettle();
      for (final label in ['As arranged', 'Name', 'Last edited', 'Kind']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.widgetWithText(CheckedPopupMenuItem<int>, 'Name'));
      await tester.pumpAndSettle();
      expect(reported, isTrue);
      expect(picked, DdxSort.name);
      expect(find.text('Name'), findsOneWidget, reason: 'the button names the current order');

      await tester.tap(find.byKey(const ValueKey('ddx-list-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckedPopupMenuItem<int>, 'As arranged'));
      await tester.pumpAndSettle();
      expect(picked, isNull);

      await tester.enterText(find.byType(TextField), 'dra');
      expect(filter, 'dra');
    });
  });

  group('DdxEmptyState', () {
    testWidgets('icon, one sentence, one button', (tester) async {
      var started = 0;
      await tester.pumpWidget(app(DdxEmptyState(
        icon: Icons.inbox_outlined,
        message: 'Nothing here yet.',
        actionLabel: 'New',
        onAction: () => started++,
      )));
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('Nothing here yet.'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is ButtonStyleButton), findsOneWidget, reason: 'never a second button');
      await tester.tap(find.text('New'));
      expect(started, 1);
    });

    testWidgets('no action, no button', (tester) async {
      await tester.pumpWidget(app(const DdxEmptyState(icon: Icons.inbox_outlined, message: 'Empty.')));
      expect(find.byWidgetPredicate((w) => w is ButtonStyleButton), findsNothing);
    });
  });

  group('helpers', () {
    test('ddxSorted: names A→Z, dates newest first, kind then name, null keeps order', () {
      final rows = [('b', '2026-01-02', 'x'), ('A', '2026-01-03', 'y'), ('c', '2026-01-01', 'x')];
      List<String> names(DdxSort? s) => [
            for (final r in ddxSorted(rows, s, name: (r) => r.$1, edited: (r) => r.$2, created: (r) => r.$2, kind: (r) => r.$3))
              r.$1,
          ];
      expect(names(null), ['b', 'A', 'c']);
      expect(names(DdxSort.name), ['A', 'b', 'c']);
      expect(names(DdxSort.edited), ['A', 'b', 'c']);
      expect(names(DdxSort.kind), ['b', 'c', 'A']);
    });

    test('ddxDateGroup: today, this week, older — the week starts where the locale says', () {
      final now = DateTime(2026, 10, 8, 15); // a Thursday
      expect(ddxDateGroup(DateTime(2026, 10, 8, 0, 5), now), DdxDateGroup.today);
      expect(ddxDateGroup(DateTime(2026, 10, 5, 9), now), DdxDateGroup.thisWeek, reason: 'Monday');
      expect(ddxDateGroup(DateTime(2026, 10, 4, 9), now), DdxDateGroup.older, reason: 'Sunday, weeks from Monday');
      expect(ddxDateGroup(DateTime(2026, 10, 4, 9), now, firstDayOfWeekIndex: 0), DdxDateGroup.thisWeek);
      expect(ddxDateGroup(DateTime(2026, 10, 9), now), DdxDateGroup.today, reason: 'a clock that moved');
    });

    test('ddxParseDbTime reads SQLite UTC', () {
      expect(ddxParseDbTime('2026-10-08 12:00:00')!.toUtc(), DateTime.utc(2026, 10, 8, 12));
      expect(ddxParseDbTime(''), isNull);
      expect(ddxParseDbTime('nonsense'), isNull);
    });

    test('ddxMatches ignores case and an empty query', () {
      expect(ddxMatches('', ['x']), isTrue);
      expect(ddxMatches('DRA', ['Dracon', null]), isTrue);
      expect(ddxMatches('zz', ['Dracon', null]), isFalse);
    });
  });
}
