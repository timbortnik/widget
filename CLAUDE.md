# Claude AI Context

This file provides context for AI assistants working on this project.

## Project Overview

**Meteogram Widget** - A Flutter mobile app with home screen widget displaying weather forecasts as a meteogram (temperature line + precipitation bars + cloud cover background).

## Quick Reference

| Aspect | Value |
|--------|-------|
| Framework | Flutter 3.x |
| Weather API | Open-Meteo (free, no key) |
| Charting | fl_chart |
| Widget package | home_widget |
| i18n | flutter_localizations + intl (ARB files) |
| State management | Provider or Riverpod |
| License | MIT |

## Key Design Decisions

- **Time range:** 2h past + 48h future with current time marker
- **Data:** Temperature (line), precipitation (bars), cloudiness (background gradient)
- **Theme:** System light/dark mode, semi-transparent widget background
- **Units:** Locale-based (°C/°F, mm/inches)
- **Update:** 30 minute refresh interval
- **Languages:** EN, DE, FR, ES, IT (extensible via ARB)

## Architecture

```
lib/
├── main.dart              # Entry point, MaterialApp setup
├── l10n/app_*.arb         # Translations with @metadata
├── models/                # Data classes for API responses
├── services/              # API client, location, units
├── theme/                 # Light/dark theme definitions
├── widgets/               # Reusable UI components (meteogram)
└── screens/               # App screens
```

## API Reference

Open-Meteo endpoint:
```
https://api.open-meteo.com/v1/forecast
  ?latitude={lat}&longitude={lon}
  &hourly=temperature_2m,precipitation,cloud_cover
  &timezone=auto
  &past_hours=2
  &forecast_days=2
```

## Coding Guidelines

- Follow Flutter/Dart conventions
- Use ARB `@` metadata for all translatable strings
- Keep widget code in `lib/widgets/`, screens in `lib/screens/`
- Services should be stateless where possible
- Prefer `const` constructors for widgets

## AI Documentation

Detailed documentation for AI context is in `docs/ai/`:
- `architecture.md` - System architecture details
- `api.md` - API integration specifics
- `i18n.md` - Localization guidelines
- `widget.md` - Home screen widget implementation

## Common Tasks

### Adding a new language
1. Copy `lib/l10n/app_en.arb` to `lib/l10n/app_<code>.arb`
2. Translate strings (keep `@` metadata)
3. Run `flutter gen-l10n`

### Modifying the chart
Edit `lib/widgets/meteogram_chart.dart` - uses fl_chart's `LineChart` with custom painting for precipitation bars and cloud gradient.

### Updating API parameters
Edit `lib/services/weather_service.dart` - see Open-Meteo docs for available parameters.
