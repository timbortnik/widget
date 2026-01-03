# Architecture

## Overview

The app follows a standard Flutter architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────┐
│                    Presentation                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   Screens   │  │   Widgets   │  │    Theme    │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
├─────────────────────────────────────────────────────┤
│                     Services                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   Weather   │  │   Location  │  │    Units    │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
├─────────────────────────────────────────────────────┤
│                      Models                          │
│  ┌─────────────────────────────────────────────────┐│
│  │              WeatherData                         ││
│  └─────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────┘
```

## Data Flow

1. **App Launch / Widget Refresh**
   - Location service gets current coordinates (GPS or saved)
   - Weather service fetches data from Open-Meteo
   - Data is parsed into `WeatherData` model
   - Units service converts values based on locale
   - UI renders meteogram chart

2. **Widget Updates**
   - Android: WorkManager triggers background update
   - iOS: WidgetKit timeline requests refresh
   - home_widget package bridges Flutter ↔ native

## State Management

Using Provider/Riverpod for lightweight state:

```dart
// Weather state
class WeatherProvider extends ChangeNotifier {
  WeatherData? _data;
  bool _loading = false;
  String? _error;

  Future<void> refresh(double lat, double lon) async { ... }
}
```

## Key Components

### MeteogramChart
The main visualization widget. Responsibilities:
- Render temperature line (fl_chart LineChart)
- Render precipitation bars (custom painter)
- Render cloud cover background gradient
- Show current time indicator
- Handle theme (light/dark) colors

### WeatherService
API client for Open-Meteo. Responsibilities:
- Build API URL with parameters
- Make HTTP request
- Parse JSON response
- Handle errors (network, API)

### UnitsService
Locale-aware unit conversion. Responsibilities:
- Detect device locale
- Convert °C ↔ °F
- Convert mm ↔ inches
- Format values for display

## Platform-Specific

### Android Widget
- `AppWidgetProvider` in Kotlin/Java
- Layout defined in XML
- WorkManager for background refresh
- home_widget renders Flutter view to bitmap

### iOS Widget
- WidgetKit extension in Swift
- Timeline provider for refresh scheduling
- home_widget provides data to native widget
