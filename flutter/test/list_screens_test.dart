import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/core/theme/app_theme.dart';
import 'package:dracondex/core/theme/tokens.g.dart';
import 'package:dracondex/data/services/assets/asset_store.dart';
import 'package:dracondex/data/services/problems_service.dart';
import 'package:dracondex/data/services/trash_service.dart';
import 'package:dracondex/features/tools/assets_screen.dart';
import 'package:dracondex/features/tools/problems_screen.dart';
import 'package:dracondex/features/tools/trash_screen.dart';
import 'package:dracondex/widgets/ddx_list.dart';

/// Procress 21 part 3: the long "manage" lists on the shared widgets —
/// Trash by when it was deleted, Problems by type, Assets by kind of file,
/// each group with its count, and every row the comfortable height.
void main() {
  Future<void> host(WidgetTester tester, Widget screen, List<Override> overrides) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.forName('midnight'),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
  }

  void rowsAreComfy(WidgetTester tester) {
    for (final e in find.byType(DdxListTile).evaluate()) {
      expect(tester.getSize(find.descendant(of: find.byWidget(e.widget), matching: find.byType(ListTile))).height,
          DdxSize.rowComfy);
    }
  }

  String db(DateTime t) => t.toUtc().toIso8601String().replaceFirst('T', ' ').split('.').first;

  testWidgets('Trash groups by today / this week / older, restore and delete trailing', (tester) async {
    final now = DateTime.now();
    final entries = [
      TrashEntry(3, null, null, 'Fresh', 'classifier', 1, db(now)),
      TrashEntry(2, null, 'Atlas', 'Middle', 'locator', 3, db(now.subtract(const Duration(days: 1)))),
      TrashEntry(1, null, null, 'Ancient', 'author', 1, db(now.subtract(const Duration(days: 30)))),
    ];
    await host(tester, const TrashScreen(nexusId: 1), [trashProvider(1).overrideWith((ref) async => entries)]);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Older'), findsOneWidget);
    // yesterday is "this week" unless the week began today
    expect(find.text('This week').evaluate().length + find.text('Today').evaluate().length, greaterThanOrEqualTo(1));
    for (final name in ['Fresh', 'Middle', 'Ancient']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byTooltip('Restore'), findsNWidgets(3));
    expect(find.byIcon(Icons.delete_forever_outlined), findsNWidgets(3));
    rowsAreComfy(tester);

    await tester.enterText(find.byType(TextField), 'anc');
    await tester.pump();
    expect(find.text('Fresh'), findsNothing);
    expect(find.text('Ancient'), findsOneWidget);
    expect(find.text('Today'), findsNothing, reason: 'an emptied group goes');

    await tester.tap(find.text('Older'));
    await tester.pump();
    expect(find.text('Ancient'), findsNothing, reason: 'folded');
  });

  testWidgets('empty Trash is the shared empty state', (tester) async {
    await host(tester, const TrashScreen(nexusId: 1), [trashProvider(1).overrideWith((ref) async => const <TrashEntry>[])]);
    expect(find.byType(DdxEmptyState), findsOneWidget);
    expect(find.text('The Trash is empty'), findsOneWidget);
  });

  testWidgets('Problems group by type with counts', (tester) async {
    final ps = [
      const Problem('link', null, 'A', 'broken [[x]]'),
      const Problem('link', null, 'B', 'broken [[y]]'),
      const Problem('empty', null, 'C', 'no content'),
    ];
    await host(tester, const ProblemsScreen(nexusId: 1), [problemsProvider(1).overrideWith((ref) async => ps)]);
    expect(find.byType(DdxListSection), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: 'the header total');
    rowsAreComfy(tester);
  });

  testWidgets('Assets group by kind of file and sort by name', (tester) async {
    final assets = [
      Asset(4, 'b.png', 'p', 'png', 2048, false, null, null),
      Asset(3, 'song.mp3', 'p', 'mp3', 100, false, null, null),
      Asset(2, 'a.png', 'p', 'png', 10, false, Uint8List(0), null),
      Asset(1, 'Site', 'https://example.com', 'url', 0, true, null, null),
    ];
    await host(tester, const AssetsScreen(nexusId: 1), [assetsProvider(1).overrideWith((ref) async => assets)]);
    expect(find.text('Images'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Links'), findsOneWidget);
    // newest first by default
    expect(tester.getTopLeft(find.text('b.png')).dy, lessThan(tester.getTopLeft(find.text('a.png')).dy));
    await tester.tap(find.byKey(const ValueKey('ddx-list-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<int>, 'Name'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('a.png')).dy, lessThan(tester.getTopLeft(find.text('b.png')).dy));
    rowsAreComfy(tester);
  });
}
