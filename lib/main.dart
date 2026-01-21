import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/widget_service.dart';
import 'services/material_you_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.initialize();

  // Load Material You colors from native Android code
  final materialYouColors = await MaterialYouService.getColors();

  runApp(MeteogramApp(materialYouColors: materialYouColors));
}

class MeteogramApp extends StatelessWidget {
  final MaterialYouColors? materialYouColors;

  const MeteogramApp({super.key, this.materialYouColors});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meteograph',
      debugShowCheckedModeBanner: false,

      // Theme - use native Material You colors if available
      theme: AppTheme.light(materialYouColors?.light),
      darkTheme: AppTheme.dark(materialYouColors?.dark),
      themeMode: ThemeMode.system,

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
        materialYouColors: materialYouColors,
      ),
    );
  }
}
