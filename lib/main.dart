import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/widget_service.dart';
import 'services/material_you_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable edge-to-edge mode (required for Android 15+)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Load Material You colors from native Android code
  final materialYouColors = await MaterialYouService.getColors();

  // Load the persisted in-app theme preference (defaults to system)
  final themeMode = await ThemeService().load();

  // Match the system bar icon brightness to the effective theme
  applySystemBarStyle(themeMode);

  runApp(MeteogramApp(
    materialYouColors: materialYouColors,
    initialThemeMode: themeMode,
  ));
}

/// Resolve [mode] to the actual brightness in effect, consulting the platform
/// brightness when the mode follows the system.
Brightness effectiveBrightness(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return Brightness.light;
    case ThemeMode.dark:
      return Brightness.dark;
    case ThemeMode.system:
      return PlatformDispatcher.instance.platformBrightness;
  }
}

/// Apply transparent edge-to-edge system bars with icon brightness that
/// contrasts the effective background for [mode]. A light background needs
/// dark icons and vice versa.
void applySystemBarStyle(ThemeMode mode) {
  final isDark = effectiveBrightness(mode) == Brightness.dark;
  final iconBrightness = isDark ? Brightness.light : Brightness.dark;
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: iconBrightness,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: iconBrightness,
  ));
}

class MeteogramApp extends StatefulWidget {
  final MaterialYouColors? materialYouColors;
  final ThemeMode initialThemeMode;

  const MeteogramApp({
    super.key,
    this.materialYouColors,
    this.initialThemeMode = ThemeMode.system,
  });

  @override
  State<MeteogramApp> createState() => _MeteogramAppState();
}

class _MeteogramAppState extends State<MeteogramApp> {
  final _themeService = ThemeService();
  late ThemeMode _themeMode = widget.initialThemeMode;

  void _setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    setState(() => _themeMode = mode);
    applySystemBarStyle(mode);
    _persistAndSyncWidget(mode);
  }

  /// Persist the choice, then refresh the widget so it re-renders with the
  /// matching theme. Saving first ensures the native provider reads the new
  /// value when the update broadcast fires.
  Future<void> _persistAndSyncWidget(ThemeMode mode) async {
    await _themeService.save(mode);
    await WidgetService().triggerWidgetUpdate();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meteograph',
      debugShowCheckedModeBanner: false,

      // Theme - use native Material You colors if available
      theme: AppTheme.light(widget.materialYouColors?.light),
      darkTheme: AppTheme.dark(widget.materialYouColors?.dark),
      themeMode: _themeMode,

      // Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,

      // Pass colors for widget rendering
      home: HomeScreen(
        materialYouColors: widget.materialYouColors,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}
