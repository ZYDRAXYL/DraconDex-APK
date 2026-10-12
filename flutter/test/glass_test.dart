import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dracondex/core/i18n/app_localizations.dart';
import 'package:dracondex/core/providers/settings_provider.dart';
import 'package:dracondex/core/theme/app_theme.dart';
import 'package:dracondex/core/theme/ddx_theme.dart';
import 'package:dracondex/core/theme/glass_probe.dart';
import 'package:dracondex/core/theme/tokens.g.dart' as tokens;
import 'package:dracondex/features/builder/builder_shell.dart';
import 'package:dracondex/widgets/ddx_glass.dart';
import 'package:dracondex/widgets/hiding_app_bar.dart';

/// The Glass UI style on APK (APP Plan.md Procress 23 part 3): which layers
/// are glass, that "Reduce transparency" and high contrast leave no blur
/// anywhere, that each theme's tint is the one SDB computed, and the
/// low-spec fallback.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// A screen with a glass-able app bar, the Navibar, and buttons that open
  /// a sheet and a dialog the way every screen does.
  Widget scene(ThemeData theme) => ProviderScope(
        child: MaterialApp(
          theme: theme,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              appBar: DdxGlassBar(child: AppBar(title: const Text('Bar'))),
              body: Column(children: [
                const HidingAppBar(appBar: _TitledBar('Hiding')),
                TextButton(
                  onPressed: () => showDdxSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => const Padding(padding: EdgeInsets.all(24), child: Text('Sheet body')),
                  ),
                  child: const Text('open sheet'),
                ),
                TextButton(
                  onPressed: () => showDdxDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(content: Text('Dialog body')),
                  ),
                  child: const Text('open dialog'),
                ),
              ]),
              bottomNavigationBar: const BuilderNavibar(location: '/'),
            ),
          ),
        ),
      );

  /// A theme change animates (MaterialApp's AnimatedTheme), and the style's
  /// switches snap half-way through it — settle before looking.
  Future<void> show(WidgetTester tester, Widget app) async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Finder glassAround(Finder f) => find.ancestor(of: f, matching: find.byType(BackdropFilter));

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
  }

  Future<void> closeAndOpenDialog(WidgetTester tester) async {
    Navigator.of(tester.element(find.text('Sheet body'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
  }

  testWidgets('Glass on: the app bars, the Navibar, a sheet and a dialog are glass', (tester) async {
    await show(tester, scene(AppTheme.forName('midnight', glass: true)));
    expect(glassAround(find.text('Bar')), findsOneWidget);
    expect(glassAround(find.text('Hiding')), findsOneWidget, reason: 'the shell screens use HidingAppBar');
    expect(glassAround(find.text('Nest')), findsOneWidget, reason: 'the Navibar');
    // page content is not
    expect(glassAround(find.text('open sheet')), findsNothing);

    await openSheet(tester);
    expect(glassAround(find.text('Sheet body')), findsOneWidget);
    // the pane draws the handle; Material's own would float outside it
    expect(find.byType(DdxGlass), findsWidgets);

    await closeAndOpenDialog(tester);
    expect(glassAround(find.text('Dialog body')), findsOneWidget);
    final dialog = tester.widget<Material>(find.descendant(of: find.byType(AlertDialog), matching: find.byType(Material)).first);
    final ddx = AppTheme.forName('midnight', glass: true).extension<DdxThemeExt>()!;
    expect(dialog.color, ddx.glassSurface, reason: "the dialog's panel takes the glass tint");
  });

  testWidgets('Glass off: nothing is glass, and the standard sheet keeps its own handle', (tester) async {
    await show(tester, scene(AppTheme.forName('midnight')));
    expect(find.byType(BackdropFilter), findsNothing);
    await openSheet(tester);
    expect(find.byType(DdxGlass), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  Future<void> expectNoBlurAnywhere(WidgetTester tester, ThemeData theme) async {
    await show(tester, scene(theme));
    expect(find.byType(DdxGlass), findsWidgets, reason: 'still the glass layout');
    expect(find.byType(BackdropFilter), findsNothing);
    await openSheet(tester);
    expect(find.byType(BackdropFilter), findsNothing);
    await closeAndOpenDialog(tester);
    expect(find.byType(BackdropFilter), findsNothing);
    // and the dialog's panel is solid surface
    final ddx = theme.extension<DdxThemeExt>()!;
    final dialog = tester.widget<Material>(find.descendant(of: find.byType(AlertDialog), matching: find.byType(Material)).first);
    expect(dialog.color, ddx.palette.surface);
  }

  testWidgets('Reduce transparency removes every BackdropFilter, panes go opaque', (tester) async {
    final theme = AppTheme.forName('daylight', glass: true, reduceTransparency: true);
    await expectNoBlurAnywhere(tester, theme);
    // every pane is the surface itself, alpha 1
    for (final e in find.byType(DdxGlass).evaluate()) {
      final box = tester.widget<DecoratedBox>(find.descendant(of: find.byWidget(e.widget), matching: find.byType(DecoratedBox)).first);
      expect((box.decoration as BoxDecoration).color, theme.extension<DdxThemeExt>()!.palette.surface);
    }
  });

  testWidgets('high contrast removes every BackdropFilter', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(highContrast: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await expectNoBlurAnywhere(tester, AppTheme.forName('moonlight', glass: true));
  });

  testWidgets("the iPhone's own translucent bar goes solid under Reduce transparency too", (tester) async {
    final ios = AppTheme.forName('midnight', reduceTransparency: true).copyWith(platform: TargetPlatform.iOS);
    await show(tester, scene(ios));
    expect(find.byType(BackdropFilter), findsNothing);
    final iosBlurred = AppTheme.forName('midnight').copyWith(platform: TargetPlatform.iOS);
    await show(tester, scene(iosBlurred));
    expect(glassAround(find.text('Nest')), findsOneWidget);
  });

  testWidgets('every theme is glazed with the tint SDB computed for it', (tester) async {
    for (final name in AppTheme.names) {
      final theme = AppTheme.forName(name, glass: true);
      final ddx = theme.extension<DdxThemeExt>()!;
      expect(ddx.glassTint, tokens.DdxGlass.glassTintFor(name), reason: name);
      await show(tester, MaterialApp(
        theme: theme,
        home: const Scaffold(body: DdxGlass(child: SizedBox(width: 100, height: 40, child: Text('pane')))),
      ));
      final pane = tester.widget<DecoratedBox>(
          find.descendant(of: find.byType(BackdropFilter), matching: find.byType(DecoratedBox)).first);
      final color = (pane.decoration as BoxDecoration).color!;
      expect(color.a, closeTo(tokens.DdxGlass.glassTintFor(name), 0.002), reason: name);
      expect(color.withValues(alpha: 1), ddx.palette.surface.withValues(alpha: 1), reason: name);
    }
    // the raised ones really are raised: not every theme is the base 72 %
    expect(AppTheme.forName('clearMeteor', glass: true).extension<DdxThemeExt>()!.glassTint, 0.83);
    expect(AppTheme.forName('midnight', glass: true).extension<DdxThemeExt>()!.glassTint, tokens.DdxGlass.glassTint);
  });

  testWidgets('a docked bar paints the backdrop gradient under its blur, a floating pane does not', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.forName('atDusk', glass: true),
      home: const Scaffold(body: Column(children: [
        DdxGlass(backdrop: true, edge: DdxGlassEdge.bottom, child: SizedBox(height: 56, width: 300)),
        DdxGlass(child: SizedBox(height: 56, width: 300)),
      ])),
    ));
    expect(find.byType(DdxGlassBackdrop), findsOneWidget);
    final docked = find.byType(DdxGlass).first;
    expect(find.descendant(of: docked, matching: find.byType(DdxGlassBackdrop)), findsOneWidget);
  });

  group('low-spec fallback', () {
    const fast = Duration(milliseconds: 8), slow = Duration(milliseconds: 30);

    test('waits for 60 frames, then decides by the median', () {
      final probe = GlassFrameProbe();
      expect(probe.add(List.filled(59, fast)), isNull);
      expect(probe.add([fast]), isFalse);
      // decided once: later frames change nothing
      expect(probe.add(List.filled(100, slow)), isFalse);
      expect(GlassFrameProbe().add(List.filled(60, slow)), isTrue);
    });

    test('a burst of slow frames around turning Glass on does not decide it', () {
      final probe = GlassFrameProbe();
      expect(probe.add([...List.filled(20, slow), ...List.filled(40, fast)]), isFalse);
      expect(GlassFrameProbe().add([...List.filled(31, slow), ...List.filled(29, fast)]), isTrue);
    });

    testWidgets('blur off keeps the tint and drops the blur', (tester) async {
      final theme = AppTheme.forName('afterRain', glass: true, glassBlurOff: true);
      await show(tester, scene(theme));
      expect(find.byType(BackdropFilter), findsNothing);
      await openSheet(tester);
      expect(find.byType(BackdropFilter), findsNothing);
      final pane = tester.widget<DecoratedBox>(
          find.descendant(of: find.ancestor(of: find.text('Sheet body'), matching: find.byType(DdxGlass)).first, matching: find.byType(DecoratedBox)).first);
      expect((pane.decoration as BoxDecoration).color!.a, closeTo(tokens.DdxGlass.glassTintFor('afterRain'), 0.002));
    });

    test('the decision is persisted, and "try again" clears it', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(settingsProvider);
      await Future<void>.delayed(Duration.zero);
      await c.read(settingsProvider.notifier).setUiStyle(UiStyle.glass);
      await c.read(settingsProvider.notifier).setGlassBlur(GlassBlur.off);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('glass_blur'), 'off');
      expect(prefs.getString('ui_style'), 'glass');

      final again = ProviderContainer();
      addTearDown(again.dispose);
      again.read(settingsProvider);
      await Future<void>.delayed(Duration.zero);
      expect(again.read(settingsProvider).glassBlur, GlassBlur.off);
      expect(again.read(settingsProvider).uiStyle, UiStyle.glass);

      await again.read(settingsProvider.notifier).setGlassBlur(GlassBlur.unmeasured);
      expect(prefs.containsKey('glass_blur'), isFalse);
    });
  });
}

class _TitledBar extends StatelessWidget implements PreferredSizeWidget {
  const _TitledBar(this.title);
  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(title: Text(title), primary: false);
}
