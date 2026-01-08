# Architecture

## Overview

The app follows a standard Flutter architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────┐
│                    Presentation                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   Screens   │  │   Widgets   │  │    Theme    │  │
│  │ (setState)  │  │NativeSvgChart│ │MeteogramColors│
│  └─────────────┘  └─────────────┘  └─────────────┘  │
├─────────────────────────────────────────────────────┤
│                     Services                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐│
│  │ Weather  │ │ Location │ │  Widget  │ │Background││
│  │ Service  │ │ Service  │ │ Service  │ │ Service ││
│  └──────────┘ └──────────┘ └──────────┘ └─────────┘│
│  ┌─────────────────────────────────────────────────┐│
│  │           SvgChartGenerator (pure Dart)        ││
│  └─────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────┤
│                      Models                          │
│  ┌─────────────────────────────────────────────────┐│
│  │              WeatherData / HourlyData           ││
│  └─────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────┘
```

## Data Flow

### App Launch
1. Location service gets current coordinates (GPS or fallback)
2. Weather service fetches data from Open-Meteo
3. Data is parsed into `WeatherData` model
4. SVG chart generated via `SvgChartGenerator`
5. In-app: SVG rendered via PlatformView (AndroidView → native ImageView)
6. Widget: SVG saved to file, native provider renders via AndroidSVG

### Widget Updates
1. Android: WorkManager triggers background update every 30 minutes
2. Background service fetches new weather data
3. SVG charts generated via `SvgChartGenerator` (works in isolate - no UI needed)
4. SVG files saved, paths stored via home_widget
5. Native `MeteogramWidgetProvider` reads SVG, renders via AndroidSVG

## State Management

Using simple `setState` in StatefulWidget (no Provider/Riverpod):

```dart
class _HomeScreenState extends State<HomeScreen> {
  WeatherData? _weatherData;
  String? _locationName;
  bool _loading = true;
  String? _error;

  Future<void> _loadWeather() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Fetch data...
      setState(() { _weatherData = weather; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }
}
```

## Key Components

### SvgChartGenerator (`lib/services/svg_chart_generator.dart`)
Pure Dart SVG generation - no Flutter UI dependencies. Responsibilities:
- Generate complete SVG string for meteogram
- Sky gradient background based on solar elevation
- Temperature line with gradient fill
- Precipitation bars
- Daylight intensity bars
- Temperature labels (min/mid/max) with proper alignment
- Time labels with locale-aware formatting (DateFormat.j)
- Width-based font sizing for consistent proportions

**Key benefit:** Works in background isolates without dart:ui

### NativeSvgChartView (`lib/widgets/native_svg_chart_view.dart`)
PlatformView wrapper for in-app SVG display. Responsibilities:
- Embed native Android ImageView via AndroidView
- Pass SVG string to native side via MethodChannel
- Bypass Flutter's image compositor for 1:1 pixel rendering

### WeatherService (`lib/services/weather_service.dart`)
API client for Open-Meteo. Responsibilities:
- Build API URL with parameters
- Request 4 hours of past data + 2 days forecast
- Make HTTP request with timeout
- Parse JSON response into WeatherData
- Handle errors (network, API, parsing)

**Data Range:** 4 hours past + 48 hours future (~52 hours total)

### LocationService (`lib/services/location_service.dart`)
Device location handling with multi-level fallback. Responsibilities:
- Get GPS coordinates via geolocator
- Handle permissions gracefully (no exceptions thrown)
- IP geolocation fallback via ip-api.com
- Reverse geocoding for city name resolution
- City search via Open-Meteo geocoding API
- Recent cities storage (last 5 selections)
- Persist location preference in SharedPreferences
- Return `LocationData` with coordinates, city name, and source

**Location Resolution Order:**
1. GPS position → reverse geocode for localized city name
2. Last known GPS position → reverse geocode
3. IP geolocation (ip-api.com) → reverse geocode for localized city name
4. Final fallback: Berlin (52.52, 13.405)

All city names are localized via reverse geocoding based on device locale.

**City Search:**
- Uses Open-Meteo geocoding API (free, no key)
- Endpoint: `https://geocoding-api.open-meteo.com/v1/search`
- Returns city name, country, region, coordinates
- Debounced search (300ms) in UI

### WidgetService (`lib/services/widget_service.dart`)
Home widget data management. Responsibilities:
- Save chart image to app documents folder
- Save widget data via HomeWidget.saveWidgetData
- Trigger native widget update

### BackgroundService (`lib/services/background_service.dart`)
WorkManager + HomeWidget integration. Responsibilities:
- Initialize WorkManager for periodic tasks
- Register HomeWidget interactivity callback for event-driven updates
- Execute background weather fetch (with caching)
- Re-render charts from cached data (no network call)
- Handle two task types: `weatherUpdateTask` (fetch+render) and `chartRenderTask` (render only)

### MeteogramColors (`lib/theme/app_theme.dart`)
Theme-aware color palette. Responsibilities:
- Provide light/dark color variants
- Color for temperature line, precipitation, now indicator
- Sky gradient based on cloud cover
- Card backgrounds and text colors

## File Structure

```
lib/
├── main.dart                    # App entry, BackgroundService init
├── l10n/                        # Localization ARB files (30+ languages)
│   ├── app_en.arb               # English
│   ├── app_de.arb               # German
│   ├── app_ar.arb               # Arabic
│   └── ...                      # 30+ locales
├── models/
│   └── weather_data.dart        # WeatherData, HourlyData models
├── screens/
│   └── home_screen.dart         # Main screen with NativeSvgChartView
├── services/
│   ├── weather_service.dart     # Open-Meteo API client
│   ├── location_service.dart    # GPS/fallback location
│   ├── widget_service.dart      # Home widget updates
│   ├── background_service.dart  # WorkManager refresh
│   └── svg_chart_generator.dart # Pure Dart SVG generation
├── theme/
│   └── app_theme.dart           # Colors, light/dark themes
└── widgets/
    └── native_svg_chart_view.dart # PlatformView SVG display

android/app/src/main/kotlin/.../
├── MainActivity.kt              # Registers PlatformView factory
├── MeteogramApplication.kt      # Application class, registers event receiver
├── WidgetEventReceiver.kt       # Handles system broadcasts (unlock, network, locale)
├── SvgChartViewFactory.kt       # Creates PlatformView instances
├── SvgChartPlatformView.kt      # Native ImageView + AndroidSVG rendering
└── MeteogramWidgetProvider.kt   # Home screen widget provider
```

## Platform-Specific

### Android Widget
- `MeteogramWidgetProvider` extends `HomeWidgetProvider`
- Layout in `res/layout/meteogram_widget.xml`
- Uses RemoteViews (limited to TextView, ImageView, LinearLayout, RelativeLayout, FrameLayout)
- Background in `res/drawable/widget_background.xml` (gradient + rounded corners)
- Chart: reads SVG file → AndroidSVG → Bitmap → ImageView

### Android In-App (PlatformView)
- `SvgChartViewFactory` registered in MainActivity
- `SvgChartPlatformView` embeds native ImageView
- Receives SVG string via MethodChannel
- Renders via AndroidSVG → Bitmap → ImageView
- Bypasses Flutter's image compositor for 1:1 pixel rendering

### iOS Widget
Not yet implemented. Would require:
- WidgetKit extension
- TimelineProvider
- App Groups for data sharing

## Error Handling

```dart
// Location errors
on LocationException catch (e) {
  // e.message: "Location permission denied" / "Location timeout"
}

// Weather errors
on WeatherException catch (e) {
  // e.message: "Failed to fetch weather data"
}

// Generic errors shown to user
catch (e) {
  setState(() { _error = e.toString(); });
}
```

## Dependencies

### Flutter/Dart
| Package | Purpose |
|---------|---------|
| home_widget | Flutter ↔ native widget bridge |
| workmanager | Background refresh scheduling |
| geolocator | GPS location |
| geocoding | Reverse geocoding (coordinates → city name) |
| http | API requests (weather + IP geolocation) |
| path_provider | App documents for SVG files |
| shared_preferences | Settings storage |
| flutter_localizations | i18n framework |
| intl | Locale-aware time formatting (DateFormat.j) |
| dynamic_color | Material You theming |

### Android Native
| Library | Purpose |
|---------|---------|
| com.caverock:androidsvg-aar | SVG parsing and rendering |

See `docs/NATIVE_SVG_RENDERING.md` for detailed rendering architecture.
