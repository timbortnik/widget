# Architecture

## Overview

The app follows a standard Flutter architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────┐
│                    Presentation                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   Screens   │  │   Widgets   │  │    Theme    │  │
│  │ (setState)  │  │ MeteogramChart│ │MeteogramColors│
│  └─────────────┘  └─────────────┘  └─────────────┘  │
├─────────────────────────────────────────────────────┤
│                     Services                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌─────────┐│
│  │ Weather  │ │ Location │ │  Widget  │ │Background││
│  │ Service  │ │ Service  │ │ Service  │ │ Service ││
│  └──────────┘ └──────────┘ └──────────┘ └─────────┘│
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
4. UI renders meteogram chart
5. Chart captured as PNG via RepaintBoundary
6. Widget updated with data + image path

### Widget Updates
1. Android: WorkManager triggers background update every 30 minutes
2. Background service fetches new weather data
3. Widget data saved to SharedPreferences via home_widget
4. Native `MeteogramWidgetProvider` reads data and updates widget

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

### MeteogramChart (`lib/widgets/meteogram_chart.dart`)
The main visualization widget using fl_chart. Responsibilities:
- Render temperature line (LineChart with gradient fill)
- Render precipitation bars (BarChart)
- Render cloud cover background (CustomPainter)
- Show current time indicator (vertical golden line)
- Support compact mode for widget
- Handle light/dark theme colors

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
WorkManager integration. Responsibilities:
- Initialize workmanager
- Register periodic task (30 min)
- Execute background weather fetch
- Update widget without UI

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
├── l10n/                        # Localization ARB files
│   ├── app_en.arb               # English
│   ├── app_de.arb               # German
│   ├── app_fr.arb               # French
│   ├── app_es.arb               # Spanish
│   ├── app_it.arb               # Italian
│   └── app_uk.arb               # Ukrainian
├── models/
│   └── weather_data.dart        # WeatherData, HourlyData models
├── screens/
│   └── home_screen.dart         # Main screen with chart capture
├── services/
│   ├── weather_service.dart     # Open-Meteo API client
│   ├── location_service.dart    # GPS/fallback location
│   ├── widget_service.dart      # Home widget updates
│   └── background_service.dart  # WorkManager refresh
├── theme/
│   └── app_theme.dart           # Colors, light/dark themes
└── widgets/
    └── meteogram_chart.dart     # fl_chart meteogram
```

## Platform-Specific

### Android Widget
- `MeteogramWidgetProvider` extends `HomeWidgetProvider`
- Layout in `res/layout/meteogram_widget.xml`
- Uses RemoteViews (limited to TextView, ImageView, LinearLayout, RelativeLayout, FrameLayout)
- Background in `res/drawable/widget_background.xml` (gradient + rounded corners)
- Chart displayed as bitmap loaded from file

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

| Package | Purpose |
|---------|---------|
| fl_chart | Temperature line + precipitation bars |
| home_widget | Flutter ↔ native widget bridge |
| workmanager | Background refresh scheduling |
| geolocator | GPS location |
| geocoding | Reverse geocoding (coordinates → city name) |
| http | API requests (weather + IP geolocation) |
| path_provider | App documents for chart image |
| shared_preferences | Settings storage |
| flutter_localizations | i18n framework |
| intl | Date/number formatting |
