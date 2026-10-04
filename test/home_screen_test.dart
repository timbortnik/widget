import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:meteogram_widget/a11y_ids.dart';
import 'package:meteogram_widget/l10n/app_localizations.dart';
import 'package:meteogram_widget/screens/home_screen.dart';
import 'package:meteogram_widget/services/material_you_service.dart';
import 'package:meteogram_widget/services/scheme_service.dart';
import 'package:meteogram_widget/theme/app_theme.dart';

/// A 1x1 transparent PNG — what the native `renderSvg` rasterizer returns,
/// minimal but valid so `Image.memory` decodes it without error.
final kTransparentPixelPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Widget tests for HomeScreen.
///
/// These tests verify UI rendering for different states:
/// - Loading state
/// - Error state
/// - Success state with weather data
///
/// Note: HomeScreen has a periodic timer for auto-refresh, so we use
/// pump() with specific durations instead of pumpAndSettle() to avoid timeouts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock data for tests - use current timestamp to avoid staleness refresh loops
  const mockTemperature = '20.5';
  late String mockTimestamp;
  const mockCityName = 'Berlin';
  const mockLocationSource = 'gps';

  /// Storage for HomeWidget mock data
  Map<String, dynamic> homeWidgetData = {};

  /// Setup mock method channels before each test
  setUp(() {
    // Use current timestamp to avoid triggering staleness refresh
    mockTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
    homeWidgetData = {};

    // Mock the native method channel: SVG generation, weather fetch, and the
    // widget-store KV API that WidgetStore drives — all on one channel.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('org.bortnik.meteogram/svg'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'saveWidgetData':
            final args = methodCall.arguments as Map;
            final id = args['id'] as String?;
            if (id != null) {
              homeWidgetData[id] = args['data'];
            }
            return true;
          case 'getWidgetData':
            final args = methodCall.arguments as Map;
            return homeWidgetData[args['id'] as String?];
          case 'updateWidget':
            return true;
          case 'fetchWeather':
            // Simulate successful fetch - populate mock data with current time
            homeWidgetData['last_weather_update'] =
                DateTime.now().millisecondsSinceEpoch.toString();
            homeWidgetData['current_temperature_celsius'] = mockTemperature;
            return true;
          case 'generateSvg':
            // Return minimal valid SVG
            return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50"></svg>';
          case 'renderSvg':
            // Native rasterizer returns PNG bytes; a 1x1 transparent PNG is
            // enough for Image.memory to decode without error.
            return kTransparentPixelPng;
          case 'reverseGeocode':
            // Native Geocoder lookup (coords -> city name)
            return mockCityName;
          // LocationBridge methods (native LocationManager)
          case 'isLocationServiceEnabled':
            return true;
          case 'checkLocationPermission':
            return 'granted';
          case 'requestLocationPermission':
            return 'granted';
          case 'getCurrentPosition':
            return {'latitude': 52.52, 'longitude': 13.405};
          case 'getLastKnownPosition':
            return {'latitude': 52.52, 'longitude': 13.405};
          case 'openLocationSettings':
            return true;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    // Clean up mock handlers
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('org.bortnik.meteogram/svg'), null);
  });

  /// Helper to wrap HomeScreen with required providers
  Widget createTestApp({MaterialYouColors? materialYouColors, Locale locale = const Locale('en')}) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      theme: AppTheme.light(null),
      darkTheme: AppTheme.dark(null),
      home: HomeScreen(materialYouColors: materialYouColors),
    );
  }

  group('HomeScreen loading state', () {
    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(createTestApp());

      // Should show loading indicator on first frame
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows loading text initially', (tester) async {
      await tester.pumpWidget(createTestApp());

      // Should show loading message (from app_en.arb)
      expect(find.text('Loading weather...'), findsOneWidget);
    });
  });

  group('HomeScreen success state', () {
    testWidgets('displays temperature after loading', (tester) async {
      // Pre-populate cache to skip loading
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = mockLocationSource;

      await tester.pumpWidget(createTestApp());
      // Use pump with duration instead of pumpAndSettle to avoid timer issues
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show temperature (69°F in US locale, or 21°C elsewhere)
      // Look for the value somewhere on screen
      final tempFinder = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data != null && widget.data!.contains('69'),
      );
      expect(tempFinder, findsWidgets);
    });

    testWidgets('renders both charts as images, not the placeholder', (tester) async {
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = mockLocationSource;

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // The Semantics(identifier:) + Image only exist once the native PNG is
      // cached; the fallback path is a bare SizedBox with neither. Asserting
      // the identifiers proves the real chart path was taken for both modes.
      Finder chartById(String id) => find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.identifier == id,
          );
      expect(chartById(A11yIds.homeHourlyChart), findsOneWidget);
      expect(chartById(A11yIds.homeWeeklyChart), findsOneWidget);
      // Each chart is a real Flutter Image over the rasterized bytes.
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('displays location name after loading', (tester) async {
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = mockLocationSource;

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show city name
      expect(find.text(mockCityName), findsOneWidget);
    });

    testWidgets('has RefreshIndicator for pull-to-refresh', (tester) async {
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = mockLocationSource;

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Should have RefreshIndicator
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('shows legend items', (tester) async {
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = mockLocationSource;

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show legend items
      expect(find.text('Daylight'), findsOneWidget);
      expect(find.text('Precipitation'), findsOneWidget);
    });

    testWidgets('shows Open-Meteo attribution', (tester) async {
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = mockLocationSource;

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show Open-Meteo attribution
      expect(find.textContaining('Open-Meteo'), findsOneWidget);
    });

    testWidgets('shows GPS indicator for GPS location', (tester) async {
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = 'gps';

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show GPS indicator
      expect(find.byIcon(Icons.gps_fixed), findsOneWidget);
    });
  });

  group('HomeScreen location picker', () {
    testWidgets('location row opens bottom sheet when tapped', (tester) async {
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = mockLocationSource;

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the location row
      await tester.tap(find.text(mockCityName));
      await tester.pump(const Duration(milliseconds: 500));

      // Should open bottom sheet with location picker
      expect(find.text('Select Location'), findsOneWidget);
    });

    testWidgets('location picker shows GPS option', (tester) async {
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = mockLocationSource;

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Open location picker
      await tester.tap(find.text(mockCityName));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show GPS option
      expect(find.text('GPS'), findsOneWidget);
      expect(find.text('Device location'), findsOneWidget);
    });

    testWidgets('location picker labels are localized', (tester) async {
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = mockLocationSource;
      // A recent city, so the "Recent" header is shown.
      homeWidgetData['recent_cities'] =
          '[{"name":"Lviv","country":"Ukraine","latitude":49.84,"longitude":24.03}]';

      await tester.pumpWidget(createTestApp(locale: const Locale('uk')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text(mockCityName));
      await tester.pump(const Duration(milliseconds: 500));
      // Recent cities load asynchronously once the sheet opens.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Місцезнаходження пристрою'), findsOneWidget);
      expect(find.text('Нещодавні'), findsOneWidget);
      expect(find.text('Device location'), findsNothing);
      expect(find.text('Recent'), findsNothing);
    });

    testWidgets('location picker has search field', (tester) async {
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = mockLocationSource;

      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Open location picker
      await tester.tap(find.text(mockCityName));
      await tester.pump(const Duration(milliseconds: 500));

      // Should have search field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search city...'), findsOneWidget);
    });
  });

  group('HomeScreen error state', () {
    testWidgets('shows error UI when no cached data and fetch fails',
        (tester) async {
      // Override to simulate fetch failure. Location methods return null here,
      // so the bridge falls back to the default location and the failing
      // fetchWeather drives the error state.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('org.bortnik.meteogram/svg'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'fetchWeather') {
            return false; // Simulate failure
          }
          return null;
        },
      );

      await tester.pumpWidget(createTestApp());
      // Wait for the error state to appear
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Should show error state with retry button
      expect(find.text('Unable to load weather'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });
  });

  group('HomeScreen dark mode', () {
    testWidgets('renders correctly in dark mode', (tester) async {
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = mockLocationSource;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.light(null),
          darkTheme: AppTheme.dark(null),
          themeMode: ThemeMode.dark,
          home: const HomeScreen(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Should render without errors in dark mode
      expect(find.byType(Scaffold), findsOneWidget);
      // Temperature should still be visible
      expect(find.textContaining('69'), findsWidgets);
    });
  });

  group('HomeScreen colour scheme picker', () {
    Finder byA11yId(String id) => find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.identifier == id,
        );

    Widget appWith({
      ChartScheme scheme = ChartScheme.defaultScheme,
      ValueChanged<ChartScheme>? onChanged,
      ThemeMode themeMode = ThemeMode.system,
    }) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.light(null),
        darkTheme: AppTheme.dark(null),
        themeMode: themeMode,
        home: HomeScreen(colorScheme: scheme, onColorSchemeChanged: onChanged),
      );
    }

    Future<void> openPicker(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(byA11yId(A11yIds.homeThemeButton));
      await tester.pumpAndSettle();
    }

    testWidgets('picker offers both theme and colour scheme sections',
        (tester) async {
      await tester.pumpWidget(appWith());
      await openPicker(tester);

      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Color scheme'), findsOneWidget);
      for (final id in [
        A11yIds.themeOptionSystem,
        A11yIds.themeOptionLight,
        A11yIds.themeOptionDark,
        A11yIds.schemeOptionDefault,
        A11yIds.schemeOptionThermal,
        A11yIds.schemeOptionHighContrast,
      ]) {
        expect(byA11yId(id), findsOneWidget, reason: '$id should be offered');
      }
    });

    /// Fill of the weather card — the one decorated container with a shadow.
    Color? cardColor(WidgetTester tester) {
      final card = tester.widgetList<Container>(find.byType(Container)).where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.boxShadow != null;
      }).single;
      return (card.decoration! as BoxDecoration).color;
    }

    Future<void> pumpWithWeather(
      WidgetTester tester,
      ChartScheme scheme, {
      ThemeMode themeMode = ThemeMode.system,
    }) async {
      homeWidgetData['last_weather_update'] = mockTimestamp;
      homeWidgetData['current_temperature_celsius'] = mockTemperature;
      homeWidgetData['cached_city_name'] = mockCityName;
      homeWidgetData['cached_location_source'] = mockLocationSource;
      await tester.pumpWidget(appWith(scheme: scheme, themeMode: themeMode));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('thermal dark card ground follows the current temperature', (tester) async {
      await pumpWithWeather(tester, ChartScheme.thermal, themeMode: ThemeMode.dark);

      expect(cardColor(tester),
          ChartScheme.thermal.groundColor(double.parse(mockTemperature), isDark: true));
    });

    testWidgets('high contrast paints the card behind the chart white',
        (tester) async {
      await pumpWithWeather(tester, ChartScheme.highContrast);

      expect(cardColor(tester), const Color(0xFFFFFFFF));
    });

    testWidgets('thermal light card ground follows the current temperature', (tester) async {
      await pumpWithWeather(tester, ChartScheme.thermal);

      expect(cardColor(tester),
          ChartScheme.thermal.groundColor(double.parse(mockTemperature), isDark: false));
      // A mild reading sits at the neutral middle, not at either tinted end.
      expect(cardColor(tester), isNot(const Color(0xFFEFE7EA)));
      expect(cardColor(tester), isNot(const Color(0xFFE4EAEF)));
    });

    testWidgets('thermal tints the current reading by its value', (tester) async {
      await pumpWithWeather(tester, ChartScheme.thermal);

      final reading = tester.widget<Text>(find.byWidgetPredicate(
        (widget) => widget is Text && widget.style?.fontSize == 64,
      ));
      expect(reading.style!.color,
          ChartScheme.thermal.temperatureColor(double.parse(mockTemperature), isDark: false));
    });

    testWidgets('thermal legend sun follows the current reading', (tester) async {
      await pumpWithWeather(tester, ChartScheme.thermal);

      final sun = tester.widget<Icon>(find.byIcon(Icons.wb_sunny_outlined));
      expect(sun.color,
          ChartScheme.thermal.daylightColor(double.parse(mockTemperature), isDark: false));
    });

    testWidgets('thermal legend shows snow beside rain', (tester) async {
      await pumpWithWeather(tester, ChartScheme.thermal);

      expect(find.byIcon(Icons.ac_unit), findsOneWidget);
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    });

    testWidgets('default legend shows a single precipitation icon', (tester) async {
      await pumpWithWeather(tester, ChartScheme.defaultScheme);

      expect(find.byIcon(Icons.ac_unit), findsNothing);
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    });

    testWidgets('the default scheme keeps the Material You card', (tester) async {
      await pumpWithWeather(tester, ChartScheme.defaultScheme);

      expect(cardColor(tester), isNot(const Color(0xFFFFFFFF)));
      expect(cardColor(tester), isNot(const Color(0xFFE7E9F4)));
    });

    testWidgets('picker marks only the active scheme as selected', (tester) async {
      await tester.pumpWidget(appWith(scheme: ChartScheme.thermal));
      await openPicker(tester);

      bool? selectedOf(String id) =>
          tester.widget<Semantics>(byA11yId(id)).properties.selected;
      expect(selectedOf(A11yIds.schemeOptionThermal), isTrue);
      expect(selectedOf(A11yIds.schemeOptionDefault), isFalse);
      expect(selectedOf(A11yIds.schemeOptionHighContrast), isFalse);
    });

    testWidgets('tapping a scheme reports the choice and closes the sheet',
        (tester) async {
      ChartScheme? picked;
      await tester.pumpWidget(appWith(onChanged: (s) => picked = s));
      await openPicker(tester);

      await tester.tap(byA11yId(A11yIds.schemeOptionThermal));
      await tester.pumpAndSettle();

      expect(picked, ChartScheme.thermal);
      expect(find.text('Color scheme'), findsNothing);
    });

    testWidgets('the active scheme is exposed as selected', (tester) async {
      await tester.pumpWidget(appWith(scheme: ChartScheme.highContrast));
      await openPicker(tester);

      Semantics semanticsFor(String id) =>
          tester.widget<Semantics>(byA11yId(id));

      // Drives both the checkmark and the E2E assertion, so it has to track
      // the active scheme rather than always reporting the default.
      expect(semanticsFor(A11yIds.schemeOptionHighContrast).properties.selected,
          isTrue);
      expect(
          semanticsFor(A11yIds.schemeOptionDefault).properties.selected, isFalse);
      expect(
          semanticsFor(A11yIds.schemeOptionThermal).properties.selected, isFalse);
    });
  });
}
