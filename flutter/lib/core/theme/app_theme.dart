import 'package:flutter/material.dart';

enum AppThemeMode { midnight, moonlight, daylight }

class AppTheme {
  static ThemeData get midnight => _build(
        bg: const Color(0xFF0F0F13),
        surface: const Color(0xFF18181F),
        raised: const Color(0xFF22222D),
        hover: const Color(0xFF2A2A38),
        border: const Color(0xFF2E2E3F),
        t1: const Color(0xFFE8E8F0),
        t2: const Color(0xFF9090A8),
        t3: const Color(0xFF5A5A72),
        accent: const Color(0xFF6366F1),
        accentH: const Color(0xFF818CF8),
        danger: const Color(0xFFEF4444),
        success: const Color(0xFF22C55E),
        brightness: Brightness.dark,
      );

  static ThemeData get moonlight => _build(
        bg: const Color(0xFF101620),
        surface: const Color(0xFF182231),
        raised: const Color(0xFF223044),
        hover: const Color(0xFF2D3B52),
        border: const Color(0xFF334258),
        t1: const Color(0xFFEDF4FF),
        t2: const Color(0xFFA6B3C7),
        t3: const Color(0xFF66758C),
        accent: const Color(0xFF7C9CFF),
        accentH: const Color(0xFF9BB5FF),
        danger: const Color(0xFFF87171),
        success: const Color(0xFF34D399),
        brightness: Brightness.dark,
      );

  static ThemeData get daylight => _build(
        bg: const Color(0xFFF4F6FB),
        surface: const Color(0xFFFFFFFF),
        raised: const Color(0xFFEEF1F7),
        hover: const Color(0xFFE2E7F0),
        border: const Color(0xFFCCD3DF),
        t1: const Color(0xFF172033),
        t2: const Color(0xFF596274),
        t3: const Color(0xFF8A94A6),
        accent: const Color(0xFF2563EB),
        accentH: const Color(0xFF3B82F6),
        danger: const Color(0xFFDC2626),
        success: const Color(0xFF16A34A),
        brightness: Brightness.light,
      );

  static ThemeData _build({
    required Color bg,
    required Color surface,
    required Color raised,
    required Color hover,
    required Color border,
    required Color t1,
    required Color t2,
    required Color t3,
    required Color accent,
    required Color accentH,
    required Color danger,
    required Color success,
    required Brightness brightness,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: brightness == Brightness.dark ? Colors.white : Colors.white,
      secondary: accentH,
      onSecondary: Colors.white,
      error: danger,
      onError: Colors.white,
      surface: surface,
      onSurface: t1,
      surfaceContainerHighest: raised,
      outline: border,
      surfaceContainer: raised,
    );

    return ThemeData(
      colorScheme: colorScheme,
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
        selectedLabelTextStyle: TextStyle(color: accent),
        unselectedLabelTextStyle: TextStyle(color: t2),
        indicatorColor: accent.withValues(alpha: 0.15),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: raised,
        selectedItemColor: accent,
        unselectedItemColor: t2,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: t1),
        bodyMedium: TextStyle(color: t1),
        bodySmall: TextStyle(color: t2),
        titleLarge: TextStyle(color: t1),
        titleMedium: TextStyle(color: t1),
        titleSmall: TextStyle(color: t2),
        labelSmall: TextStyle(color: t3),
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
        labelStyle: TextStyle(color: t2),
        hintStyle: TextStyle(color: t3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: raised,
        labelStyle: TextStyle(color: t1),
        side: BorderSide(color: border),
      ),
      listTileTheme: ListTileThemeData(
        textColor: t1,
        iconColor: t2,
        tileColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: raised,
        textStyle: TextStyle(color: t1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        titleTextStyle: TextStyle(color: t1, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: t2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static ThemeData forMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.midnight:
        return midnight;
      case AppThemeMode.moonlight:
        return moonlight;
      case AppThemeMode.daylight:
        return daylight;
    }
  }
}
