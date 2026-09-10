import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/i18n/app_localizations.dart';
import 'core/providers/settings_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class DraconDexApp extends ConsumerWidget {
  const DraconDexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final themeData = switch (settings.theme) {
      AppThemeMode.midnight => AppTheme.midnight,
      AppThemeMode.moonlight => AppTheme.moonlight,
      AppThemeMode.daylight => AppTheme.daylight,
    };

    return MaterialApp.router(
      title: 'DraconDex',
      theme: themeData,
      routerConfig: appRouter,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) {
        // Apply uiScale through the app's own live MediaQuery
        // (MediaQuery.of(context), sourced from MaterialApp's internal View
        // widget) instead of reconstructing one via MediaQueryData.fromView().
        // That snapshot was taken once per DraconDexApp rebuild and never
        // refreshed itself when the OS reported the real status-bar/notch
        // insets shortly after cold start (this widget has no
        // WidgetsBindingObserver to react to that changing), so content sat
        // under the status bar until something else — e.g. touching this
        // very setting — forced a rebuild and recaptured the now-correct
        // padding. MediaQuery.of(context) here is always current.
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(settings.uiScale)),
          child: child!,
        );
      },
    );
  }
}
