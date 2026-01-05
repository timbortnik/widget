import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/widget_service.dart';
import 'services/background_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.initialize();
  await BackgroundService.initialize();
  await BackgroundService.registerPeriodicTask();
  runApp(const MeteogramApp());
}

class MeteogramApp extends StatelessWidget {
  const MeteogramApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use DynamicColorBuilder to get Material You colors from system
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Meteogram',
          debugShowCheckedModeBanner: false,

          // Theme - use dynamic colors if available
          theme: AppTheme.light(lightDynamic),
          darkTheme: AppTheme.dark(darkDynamic),
          themeMode: ThemeMode.system,

          // Localization
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,

          // Pass both color schemes for widget rendering
          home: HomeScreen(
            lightColorScheme: lightDynamic,
            darkColorScheme: darkDynamic,
          ),
        );
      },
    );
  }
}
