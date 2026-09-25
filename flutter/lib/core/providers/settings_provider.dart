import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/module_model.dart';
import '../theme/app_theme.dart';

class AppSettings {
  /// A key of ddxPalettes (tokens.g.dart) — midnight, daylight, atDusk, …
  final String theme;
  final Locale locale;
  final double uiScale;

  /// Kind names as the desktop's default "classic" mode shows them — Folder,
  /// Category, Timeline, in the UI language — or the "unique" proper names
  /// (Collector, Classifier, Chronicler). EXE core/state.js nameMode.
  final bool classicNames;

  const AppSettings({
    this.theme = AppTheme.fallback,
    this.locale = const Locale('en'),
    this.uiScale = 1.0,
    this.classicNames = true,
  });

  AppSettings copyWith({String? theme, Locale? locale, double? uiScale, bool? classicNames}) {
    return AppSettings(
      theme: theme ?? this.theme,
      locale: locale ?? this.locale,
      uiScale: uiScale ?? this.uiScale,
      classicNames: classicNames ?? this.classicNames,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  static const _keyTheme = 'theme';
  static const _keyLocale = 'locale';
  static const _keyScale = 'ui_scale';
  static const _keyNameMode = 'name_mode';

  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_keyTheme) ?? 'midnight';
    final localeStr = prefs.getString(_keyLocale) ?? 'en';
    final scale = prefs.getDouble(_keyScale) ?? 1.0;
    final classic = prefs.getString(_keyNameMode) != 'unique';
    KindNames.classic = classic;

    // The pref has always held the theme's name, so the three names saved
    // before APK had 32 themes are keys here too. Anything unknown (a theme
    // removed from tokens.json) falls back rather than rendering nothing.
    final theme = AppTheme.exists(themeStr) ? themeStr : AppTheme.fallback;

    state = AppSettings(
      theme: theme,
      locale: Locale(localeStr),
      uiScale: scale,
      classicNames: classic,
    );
  }

  Future<void> setTheme(String theme) async {
    if (!AppTheme.exists(theme)) return;
    state = state.copyWith(theme: theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, theme);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale.languageCode);
  }

  Future<void> setClassicNames(bool classic) async {
    KindNames.classic = classic;
    state = state.copyWith(classicNames: classic);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNameMode, classic ? 'classic' : 'unique');
  }

  Future<void> setUiScale(double scale) async {
    state = state.copyWith(uiScale: scale.clamp(0.5, 2.0));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyScale, state.uiScale);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
