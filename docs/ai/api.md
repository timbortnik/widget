# Open-Meteo API Integration

## Endpoint

```
GET https://api.open-meteo.com/v1/forecast
```

No API key required. Free for non-commercial use.

## Request Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `latitude` | float | Location latitude |
| `longitude` | float | Location longitude |
| `hourly` | string | Comma-separated variables |
| `timezone` | `auto` | Auto-detect from coordinates |
| `past_hours` | `6` | Hours of historical data |
| `forecast_days` | `2` | Days of forecast |

### Hourly Variables Used

| Variable | Unit | Description |
|----------|------|-------------|
| `temperature_2m` | °C | Temperature at 2 meters |
| `precipitation` | mm | Rain + snow water equivalent |
| `cloud_cover` | % | Total cloud cover (0-100) |

## Example Request

```
https://api.open-meteo.com/v1/forecast
  ?latitude=52.52
  &longitude=13.41
  &hourly=temperature_2m,precipitation,cloud_cover
  &timezone=auto
  &past_hours=6
  &forecast_days=2
```

## Example Response

```json
{
  "latitude": 52.52,
  "longitude": 13.419998,
  "timezone": "Europe/Berlin",
  "hourly_units": {
    "time": "iso8601",
    "temperature_2m": "°C",
    "precipitation": "mm",
    "cloud_cover": "%"
  },
  "hourly": {
    "time": [
      "2024-01-15T10:00",
      "2024-01-15T11:00",
      "2024-01-15T12:00",
      ...
    ],
    "temperature_2m": [5.2, 6.1, 7.3, ...],
    "precipitation": [0.0, 0.1, 0.0, ...],
    "cloud_cover": [45, 60, 80, ...]
  }
}
```

## Data Model

```dart
class WeatherData {
  final String timezone;
  final List<HourlyData> hourly;
  final DateTime fetchedAt;
}

class HourlyData {
  final DateTime time;
  final double temperature;  // Always stored as °C
  final double precipitation; // Always stored as mm
  final int cloudCover;      // 0-100%
}
```

## Error Handling

| HTTP Code | Meaning | Action |
|-----------|---------|--------|
| 200 | Success | Parse response |
| 400 | Bad request | Check parameters |
| 429 | Rate limited | Retry with backoff |
| 5xx | Server error | Retry later |

## Rate Limits

- 10,000 requests/day for non-commercial use
- With 30-min refresh, single user = ~48 requests/day
- No concerns for typical usage

## Caching Strategy

- Cache response in SharedPreferences
- Show cached data while refreshing
- Display "last updated" time
- Max cache age: 1 hour (show stale warning)

## Additional Variables (Future)

If expanding the meteogram, useful variables:
- `wind_speed_10m` - Wind speed
- `relative_humidity_2m` - Humidity
- `pressure_msl` - Sea level pressure
- `uv_index` - UV index
- `is_day` - Day/night indicator
