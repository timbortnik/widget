import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:meteogram_widget/l10n/app_localizations.dart';
import 'package:meteogram_widget/screens/home_screen.dart';
import 'package:meteogram_widget/services/material_you_service.dart';
import 'package:meteogram_widget/theme/app_theme.dart';

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

    // Mock HomeWidget method channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'saveWidgetData':
            final args = methodCall.arguments as Map;
            final id = args['id'] as String?;
            final data = args['data'];
            if (id != null) {
              homeWidgetData[id] = data;
            }
            return true;
          case 'getWidgetData':
            final args = methodCall.arguments as Map;
            final id = args['id'] as String?;
            final defaultValue = args['defaultValue'];
            return homeWidgetData[id] ?? defaultValue;
          case 'updateWidget':
            return true;
          case 'setAppGroupId':
            return true;
          case 'registerBackgroundCallback':
            return true;
          default:
            return null;
        }
      },
    );

    // Mock native SVG method channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('org.bortnik.meteogram/svg'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'fetchWeather':
            // Simulate successful fetch - populate mock data with current time
            homeWidgetData['last_weather_update'] =
                DateTime.now().millisecondsSinceEpoch.toString();
            homeWidgetData['current_temperature_celsius'] = mockTemperature;
            return true;
          case 'generateSvg':
            // Return minimal valid SVG
            return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50"></svg>';
          default:
            return null;
        }
      },
    );

    // Mock geolocator channel (for LocationService)
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'checkPermission':
            return 3; // LocationPermission.whileInUse
          case 'isLocationServiceEnabled':
            return true;
          case 'getCurrentPosition':
            return {
              'latitude': 52.52,
              'longitude': 13.405,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'accuracy': 10.0,
              'altitude': 0.0,
              'heading': 0.0,
              'speed': 0.0,
              'speedAccuracy': 0.0,
              'altitudeAccuracy': 0.0,
              'headingAccuracy': 0.0,
            };
          default:
            return null;
        }
      },
    );

    // Mock geocoding channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geocoding'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'placemarkFromCoordinates':
            return [
              {
                'locality': mockCityName,
                'country': 'Germany',
                'isoCountryCode': 'DE',
              }
            ];
          default:
            return null;
        }
      },
    );

    // Mock shared_preferences channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  tearDown(() {
    // Clean up mock handlers
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('org.bortnik.meteogram/svg'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/geolocator'), null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/geocoding'), null);
  });

  /// Helper to wrap HomeScreen with required providers
  Widget createTestApp({MaterialYouColors? materialYouColors}) {
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
      // Override to simulate fetch failure
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

      // Make geolocator fail
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/geolocator'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getCurrentPosition') {
            throw PlatformException(code: 'PERMISSION_DENIED');
          }
          if (methodCall.method == 'checkPermission') {
            return 0; // denied
          }
          if (methodCall.method == 'isLocationServiceEnabled') {
            return true;
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
}
