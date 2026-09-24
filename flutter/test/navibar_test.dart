import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/features/builder/breadcrumb_title.dart';
import 'package:dracondex/features/builder/builder_shell.dart';

/// The phone shell of APK V3 (APP docs/APK-V3.md §10.1, §10.5): five Navibar
/// slots, and a Navibar that steps aside on the way down a page.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app(Widget child) => ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: child,
          ),
        ),
      );

  testWidgets('the Navibar has the five slots, in order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const Scaffold(bottomNavigationBar: BuilderNavibar(location: '/'))));
    final labels = ['Nest', 'Search', 'Pages', 'Tools', 'More'];
    for (final l in labels) {
      expect(find.text(l), findsOneWidget);
    }
    final xs = [for (final l in labels) tester.getCenter(find.text(l)).dx];
    expect(xs, [...xs]..sort());
  });

  testWidgets('scrolling down hides the Navibar, scrolling up brings it back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final list = ListView(children: [for (var i = 0; i < 80; i++) SizedBox(height: 60, child: Text('row $i'))]);
    await tester.pumpWidget(app(BuilderShell(location: '/', child: list)));
    expect(find.byType(BuilderNavibar), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byType(BuilderNavibar), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(find.byType(BuilderNavibar), findsOneWidget);
  });

  testWidgets('the breadcrumb title folds a long path into a leading …', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final crumbs = [
      const Crumb(label: 'World', nexusId: 1),
      for (final (i, name) in ['Places', 'North', 'Keep'].indexed) Crumb(label: name, nexusId: 1, moduleId: i + 1),
      const Crumb(label: 'Arin', nexusId: 1, moduleId: 3, itemKey: 'cobj_9'),
    ];
    await tester.pumpWidget(app(Scaffold(appBar: AppBar(title: BreadcrumbTitle(crumbs: crumbs)))));
    // A phone's app bar keeps the page and its parent.
    expect(find.text('…'), findsOneWidget);
    for (final hidden in ['World', 'Places', 'North']) {
      expect(find.text(hidden), findsNothing);
    }
    for (final shown in ['Keep', 'Arin']) {
      expect(find.text(shown), findsOneWidget);
    }
    expect([BreadcrumbTitle.keepFor(300), BreadcrumbTitle.keepFor(500), BreadcrumbTitle.keepFor(900)], [2, 3, 4]);
  });
}
