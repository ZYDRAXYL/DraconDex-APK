// Port Link 9.6 — the "changed on both sides" sheet answers with the keys the
// merge asks by; the mark and the menu stay out of the way where there is no SAF.
import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/core/platform/saf.dart';
import 'package:dracondex/data/services/portlink/portlink_merge.dart';
import 'package:dracondex/data/services/portlink/portlink_service.dart';
import 'package:dracondex/features/settings/port_drive_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const conflicts = [
    PortlinkConflict(key: 'classifier_object:5:name', table: 'classifier_object', id: 5, col: 'name', local: 'Phone', drive: 'Drive', label: 'A'),
    PortlinkConflict(key: 'classifier_object:5:note', table: 'classifier_object', id: 5, col: 'note', local: 'p', drive: 'd', label: 'A'),
  ];

  Future<Map<String, String>?> open(WidgetTester t, Future<void> Function() act) async {
    Map<String, String>? got;
    await t.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () async => got = await showModalBottomSheet<Map<String, String>>(
                context: ctx, isScrollControlled: true, builder: (_) => const PortConflictSheet(conflicts: conflicts)),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.text('Changed on both sides'), findsOneWidget);
    await act();
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    return got;
  }

  testWidgets('every cell defaults to this phone', (t) async {
    expect(await open(t, () async {}), {'classifier_object:5:name': 'local', 'classifier_object:5:note': 'local'});
  });

  testWidgets('"All: drive" answers every cell with the drive', (t) async {
    expect(await open(t, () async {
      await t.tap(find.text('All: drive'));
      await t.pump();
    }), {'classifier_object:5:name': 'drive', 'classifier_object:5:note': 'drive'});
  });

  testWidgets('no SAF (iOS, the PWA): no mark', (t) async {
    Saf.supportedOverride = false;
    addTearDown(() => Saf.supportedOverride = null);
    await t.pumpWidget(const ProviderScope(child: MaterialApp(home: PortLinkMark(nexusId: 1))));
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('an outcome code becomes words; an unknown one keeps its code', (t) async {
    await t.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return Column(children: [
          Text(portMessage(l10n, const PortResult.fail('drive_changed'))),
          Text(portMessage(l10n, const PortResult.fail('weird'))),
          Text(portMessage(l10n, const PortResult.ok(unchanged: true))),
        ]);
      }),
    ));
    expect(find.text('The drive changed meanwhile — try again'), findsOneWidget);
    expect(find.text("Couldn't sync (weird)"), findsOneWidget);
    expect(find.text('Already up to date'), findsOneWidget);
  });
}
