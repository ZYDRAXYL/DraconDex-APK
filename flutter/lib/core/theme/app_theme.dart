import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'ddx_theme.dart';
import 'tokens.g.dart';

/// The app's themes: every palette in DraconDex-SDB's design/tokens.json
/// (tokens.g.dart, vendored), the same 32 the desktop has — APK had 3
/// hand-copied ones before Procress 13 part 5. A theme is chosen by its key.
class AppTheme {
  static const String fallback = 'midnight';

  /// The themes in the order the picker shows them: the three basics first,
  /// the way the desktop's collapsed Appearance page does.
  static List<String> get names {
    const basics = ['daylight', 'moonlight', 'midnight'];
    return [...basics, ...ddxPalettes.keys.where((k) => !basics.contains(k))];
  }

  static bool exists(String name) => ddxPalettes.containsKey(name);

  /// "atDusk" → "AtDusk": theme names are proper nouns and the desktop shows
  /// them the same in every language.
  static String label(String name) => name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);

  static ThemeData forName(String name) {
    final key = exists(name) ? name : fallback;
    final p = ddxPalettes[key]!;
    return _build(
      name: key,
      palette: p,
      bg: p.bg,
      surface: p.surface,
      raised: p.raised,
      hover: p.hover,
      border: p.border,
      t1: p.t1,
      t2: p.t2,
      muted: p.t3Aa,
      accent: p.accent,
      accentH: p.accentH,
      danger: p.danger,
      success: p.success,
      onAccent: p.onButton ?? p.onAccent ?? Colors.white,
      brightness: isLight(p.bg) ? Brightness.light : Brightness.dark,
    );
  }

  /// WCAG relative luminance above 0.179 — where dark text starts to beat
  /// white. The same rule EXE uses for a package theme's tone.
  static bool isLight(Color c) => c.computeLuminance() > 0.179;

  static ThemeData _build({
    required String name,
    required DdxPalette palette,
    required Color bg,
    required Color surface,
    required Color raised,
    required Color hover,
    required Color border,
    required Color t1,
    required Color t2,
    required Color muted,
    required Color accent,
    required Color accentH,
    required Color danger,
    required Color success,
    required Color onAccent,
    required Brightness brightness,
  }) {
    // iOS body text is 17pt (REDESIGN.md C3); Android keeps Material's.
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      secondary: accentH,
      onSecondary: Colors.white,
      error: danger,
      onError: Colors.white,
      surface: surface,
      onSurface: t1,
      surfaceContainerHighest: raised,
      outline: border,
      // Material's own secondary text (and every view here that asks for
      // it) reads onSurfaceVariant — the AA-lifted muted colour, not t3.
      onSurfaceVariant: muted,
      outlineVariant: border,
      surfaceContainer: raised,
    );

    return ThemeData(
      colorScheme: colorScheme,
      extensions: [DdxThemeExt(name: name, palette: palette)],
      scaffoldBackgroundColor: bg,
      cardColor: surface,
      dividerColor: border,
      fontFamily: 'NotoSans',
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: t1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: raised),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: raised,
        selectedIconTheme: IconThemeData(color: accent),
        unselectedIconTheme: IconThemeData(color: t2),
        selectedLabelTextStyle: TextStyle(color: accent, fontFamily: 'NotoSans'),
        unselectedLabelTextStyle: TextStyle(color: t2, fontFamily: 'NotoSans'),
        indicatorColor: accent.withValues(alpha: 0.15),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: raised,
        selectedItemColor: accent,
        unselectedItemColor: t2,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: t1, fontSize: ios ? 17 : null),
        bodyMedium: TextStyle(color: t1),
        bodySmall: TextStyle(color: t2),
        titleLarge: TextStyle(color: t1),
        titleMedium: TextStyle(color: t1),
        titleSmall: TextStyle(color: t2),
        // Muted TEXT uses t3-aa (4.5:1), not t3 — REDESIGN.md C4.
        labelSmall: TextStyle(color: muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        // The component contract's form states (APP docs/redesign/COMPONENTS.md):
        // help under a field in muted text, the same line red on error, and
        // the border red with it — the desktop's .help / .help.err / aria-invalid.
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: danger, width: 2),
        ),
        labelStyle: TextStyle(color: t2, fontFamily: 'NotoSans'),
        hintStyle: TextStyle(color: muted, fontFamily: 'NotoSans'),
        helperStyle: TextStyle(color: muted, fontFamily: 'NotoSans'),
        errorStyle: TextStyle(color: danger, fontFamily: 'NotoSans'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      // The contract's four buttons: primary (Filled / Elevated), secondary
      // (Outlined), ghost (Text) and danger (DdxDangerButton, on error).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          textStyle: const TextStyle(fontFamily: 'NotoSans', fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t1,
          backgroundColor: raised,
          side: BorderSide(color: border),
          textStyle: const TextStyle(fontFamily: 'NotoSans'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : raised),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? onAccent : t2),
          textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: 'NotoSans')),
        ),
      ),
      // Toasts: the raised surface, not Material's inverted one, so a toast
      // reads as part of the theme; its action (Undo, Retry) in the accent.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: raised,
        contentTextStyle: TextStyle(color: t1, fontFamily: 'NotoSans'),
        actionTextColor: accentH,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: onAccent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raised,
        // The family too: a style given here replaces the theme's, and the web
        // build bundles no fallback font — without it the label draws nothing.
        labelStyle: TextStyle(color: t1, fontFamily: 'NotoSans'),
        side: BorderSide(color: border),
      ),
      listTileTheme: ListTileThemeData(
        textColor: t1,
        iconColor: t2,
        tileColor: Colors.transparent,
        selectedColor: t1,
        selectedTileColor: accent.withValues(alpha: 0.14),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: raised,
        textStyle: TextStyle(color: t1, fontFamily: 'NotoSans'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        titleTextStyle: TextStyle(color: t1, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'NotoSans'),
        contentTextStyle: TextStyle(color: t2, fontFamily: 'NotoSans'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
