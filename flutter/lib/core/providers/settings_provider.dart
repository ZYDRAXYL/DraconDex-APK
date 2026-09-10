import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class AppSettings {
  final AppThemeMode theme;
  final Locale locale;
  final double uiScale;

  const AppSettings({
    this.theme = AppThemeMode.midnight,
    this.locale = const Locale('en'),
    this.uiScale = 1.0,
  });

  AppSettings copyWith({AppThemeMode? theme, Locale? locale, double? uiScale}) {
    return AppSettings(
      theme: theme ?? this.theme,
      locale: locale ?? this.locale,
      uiScale: uiScale ?? this.uiScale,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  static const _keyTheme = 'theme';
  static const _keyLocale = 'locale';
  static const _keyScale = 'ui_scale';

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

    AppThemeMode theme;
    switch (themeStr) {
      case 'daylight':
        theme = AppThemeMode.daylight;
        break;
      case 'moonlight':
        theme = AppThemeMode.moonlight;
        break;
      default:
        theme = AppThemeMode.midnight;
    }

    state = AppSettings(
      theme: theme,
      locale: Locale(localeStr),
      uiScale: scale,
    );
  }

  Future<void> setTheme(AppThemeMode theme) async {
    state = state.copyWith(theme: theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, theme.name);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale.languageCode);
  }

  Future<void> setUiScale(double scale) async {
    state = state.copyWith(uiScale: scale.clamp(0.5, 2.0));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyScale, state.uiScale);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
