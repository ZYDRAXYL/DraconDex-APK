import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/module_model.dart';
import '../theme/app_theme.dart';

/// How the chrome is drawn, over whichever theme (APP Plan.md Procress 23) —
/// the desktop's body[data-ui-style]. [standard] is the platform's own look:
/// Material on Android, the Apple layer on iPhone/iPad (context.isIosStyle).
/// [glass] keeps that and draws the bars and the floating layers as
/// translucent, blurred panes (widgets/ddx_glass.dart). A style is not a
/// palette, so it combines with all 32 themes.
enum UiStyle { standard, glass }

/// What the first frames under Glass said about this device: [off] means it
/// drew the blur too slowly, so the panes keep their tint and lose the blur
/// (core/theme/glass_probe.dart). Kept until the user asks to try again.
enum GlassBlur { unmeasured, on, off }

class AppSettings {
  /// A key of ddxPalettes (tokens.g.dart) — midnight, daylight, atDusk, …
  final String theme;
  final Locale locale;
  final double uiScale;

  /// Kind names as the desktop's default "classic" mode shows them — Folder,
  /// Category, Timeline, in the UI language — or the "unique" proper names
  /// (Collector, Classifier, Chronicler). EXE core/state.js nameMode.
  final bool classicNames;

  final UiStyle uiStyle;

  /// The app's own "Reduce transparency": every glass pane becomes the same
  /// surface, opaque. The OS's high-contrast mode does the same on its own.
  final bool reduceTransparency;

  final GlassBlur glassBlur;

  const AppSettings({
    this.theme = AppTheme.fallback,
    this.locale = const Locale('en'),
    this.uiScale = 1.0,
    this.classicNames = true,
    this.uiStyle = UiStyle.standard,
    this.reduceTransparency = false,
    this.glassBlur = GlassBlur.unmeasured,
  });

  bool get glass => uiStyle == UiStyle.glass;

  AppSettings copyWith({
    String? theme,
    Locale? locale,
    double? uiScale,
    bool? classicNames,
    UiStyle? uiStyle,
    bool? reduceTransparency,
    GlassBlur? glassBlur,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      locale: locale ?? this.locale,
      uiScale: uiScale ?? this.uiScale,
      classicNames: classicNames ?? this.classicNames,
      uiStyle: uiStyle ?? this.uiStyle,
      reduceTransparency: reduceTransparency ?? this.reduceTransparency,
      glassBlur: glassBlur ?? this.glassBlur,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  static const _keyTheme = 'theme';
  static const _keyLocale = 'locale';
  static const _keyScale = 'ui_scale';
  static const _keyNameMode = 'name_mode';
  static const _keyUiStyle = 'ui_style';
  static const _keyReduceTransparency = 'reduce_transparency';
  static const _keyGlassBlur = 'glass_blur';

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
      // An unknown name (a style from a newer build) reads as the standard one.
      uiStyle: prefs.getString(_keyUiStyle) == 'glass' ? UiStyle.glass : UiStyle.standard,
      reduceTransparency: prefs.getBool(_keyReduceTransparency) ?? false,
      glassBlur: switch (prefs.getString(_keyGlassBlur)) {
        'on' => GlassBlur.on,
        'off' => GlassBlur.off,
        _ => GlassBlur.unmeasured,
      },
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

  Future<void> setUiStyle(UiStyle style) async {
    state = state.copyWith(uiStyle: style);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUiStyle, style.name);
  }

  Future<void> setReduceTransparency(bool on) async {
    state = state.copyWith(reduceTransparency: on);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReduceTransparency, on);
  }

  /// The low-spec verdict, or [GlassBlur.unmeasured] to measure again.
  Future<void> setGlassBlur(GlassBlur blur) async {
    state = state.copyWith(glassBlur: blur);
    final prefs = await SharedPreferences.getInstance();
    if (blur == GlassBlur.unmeasured) {
      await prefs.remove(_keyGlassBlur);
    } else {
      await prefs.setString(_keyGlassBlur, blur.name);
    }
  }

  Future<void> setUiScale(double scale) async {
    state = state.copyWith(uiScale: scale.clamp(0.5, 2.0));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyScale, state.uiScale);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
