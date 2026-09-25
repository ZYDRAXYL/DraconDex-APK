import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/core/layout/breakpoints.dart';
import 'package:dracondex/core/providers/settings_provider.dart';
import 'package:dracondex/core/theme/app_theme.dart';
import 'package:dracondex/core/theme/ddx_theme.dart';
import 'package:dracondex/core/theme/tokens.g.dart';
import 'package:dracondex/features/page/page_header.dart';
import 'package:dracondex/widgets/row_menu.dart';

/// Procress 13 part 5 (APP docs/REDESIGN.md C3–C6, G7): the SDB design
/// tokens as themes, the iOS layer, the per-page title layout.
void main() {
  group('themes from tokens.g.dart', () {
    test('all 32 palettes build a theme carrying DdxThemeExt', () {
      expect(ddxPalettes.length, 32);
      for (final name in AppTheme.names) {
        final t = AppTheme.forName(name);
        final ext = t.extension<DdxThemeExt>();
        expect(ext, isNotNull, reason: name);
        expect(ext!.name, name);
        // Muted text is the AA-lifted colour everywhere Material asks for it.
        expect(t.colorScheme.onSurfaceVariant, ddxPalettes[name]!.t3Aa, reason: name);
      }
    });

    test('the three basics come first, in the desktop\'s order', () {
      expect(AppTheme.names.take(3), ['daylight', 'moonlight', 'midnight']);
      expect(AppTheme.names.toSet().length, 32);
    });

    test('brightness follows the palette', () {
      expect(AppTheme.forName('daylight').brightness, Brightness.light);
      expect(AppTheme.forName('midnight').brightness, Brightness.dark);
      expect(AppTheme.forName('atDawn').brightness, Brightness.light);
    });

    test('an unknown name falls back to midnight', () {
      expect(AppTheme.forName('noSuchTheme').extension<DdxThemeExt>()!.name, 'midnight');
    });

    test('a theme saved before there were 32 still loads, a gone one falls back', () async {
      for (final (saved, want) in [('daylight', 'daylight'), ('moonlight', 'moonlight'), ('clearSky', 'clearSky'), ('removed', 'midnight')]) {
        SharedPreferences.setMockInitialValues({'theme': saved});
        final c = ProviderContainer();
        c.read(settingsProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(c.read(settingsProvider).theme, want, reason: saved);
        c.dispose();
      }
    });
  });

  group('page title layout', () {
    test('parses what EXE writes, and survives what it should not', () {
      final sha = 'a' * 64;
      final l = PageHeadLayout.parse('{"align":"center","cover":"$sha","icon":"🐉"}');
      expect(l.align, 'center');
      expect(l.cover, sha);
      expect(l.icon, '🐉');
      for (final raw in [null, '', '   ', 'not json', '[]', '{"align":"diagonal","cover":"x"}']) {
        final d = PageHeadLayout.parse(raw);
        expect(d.align, 'left', reason: '$raw');
        expect(d.cover, isNull, reason: '$raw');
      }
    });

    test('the default is stored as empty, like EXE', () {
      expect(PageHeadLayout.empty.encode(), '');
      expect(const PageHeadLayout(align: 'right').encode(), contains('"right"'));
      expect(pageHeadKey(null), 'pageHead');
      expect(pageHeadKey('cobj_12'), 'pageHead:cobj_12');
    });
  });

  test('the hub panel stays open from 840dp (G7)', () {
    expect(ddxLayoutForSize(const Size(850, 700)), DdxLayoutClass.wide);
    expect(ddxLayoutForSize(const Size(830, 700)), DdxLayoutClass.tablet);
  });

  testWidgets('on iOS a row menu is an action sheet', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.forName('midnight').copyWith(platform: TargetPlatform.iOS),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showRowMenu(context, [
            RowAction(label: 'Rename', icon: Icons.edit, onTap: () {}),
            RowAction(label: 'Delete', icon: Icons.delete, onTap: () {}, danger: true),
          ]),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
