/// Hours of past data to request from API.
const int kPastHours = 6;

/// Hours of future data to display on chart.
const int kForecastHours = 46;

/// Total display range in hours (past + forecast).
const int kDisplayRangeHours = kPastHours + kForecastHours;

/// Weather data model for Open-Meteo API response.
class WeatherData {
  final String timezone;
  final double latitude;
  final double longitude;
  final List<HourlyData> hourly;
  final DateTime fetchedAt;

  WeatherData({
    required this.timezone,
    required this.latitude,
    required this.longitude,
    required this.hourly,
    required this.fetchedAt,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final hourlyJson = json['hourly'] as Map<String, dynamic>;
    final times = (hourlyJson['time'] as List);
    final temperatures = (hourlyJson['temperature_2m'] as List);
    final precipitation = (hourlyJson['precipitation'] as List);
    final cloudCover = (hourlyJson['cloud_cover'] as List);

    // Validate array lengths match to prevent index errors
    final minLength = [times.length, temperatures.length, precipitation.length, cloudCover.length]
        .reduce((a, b) => a < b ? a : b);

    final hourlyData = <HourlyData>[];
    for (var i = 0; i < minLength; i++) {
      // Skip entries with null values
      if (times[i] == null || temperatures[i] == null) continue;

      hourlyData.add(HourlyData(
        time: DateTime.parse(times[i] as String),
        temperature: (temperatures[i] as num).toDouble(),
        precipitation: (precipitation[i] as num?)?.toDouble() ?? 0.0,
        cloudCover: (cloudCover[i] as num?)?.toInt() ?? 0,
      ));
    }

    return WeatherData(
      timezone: json['timezone'] as String? ?? 'UTC',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      hourly: hourlyData,
      fetchedAt: json['fetchedAt'] != null
          ? DateTime.parse(json['fetchedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'timezone': timezone,
        'latitude': latitude,
        'longitude': longitude,
        'fetchedAt': fetchedAt.toIso8601String(),
        'hourly': {
          'time': hourly.map((h) => h.time.toIso8601String()).toList(),
          'temperature_2m': hourly.map((h) => h.temperature).toList(),
          'precipitation': hourly.map((h) => h.precipitation).toList(),
          'cloud_cover': hourly.map((h) => h.cloudCover).toList(),
        },
      };

  /// Get data for display range: past hours + forecast hours.
  /// Returns a slice of hourly data centered on "now".
  List<HourlyData> getDisplayRange() {
    // API returns: kPastHours + forecast_days (2) * 24 hours
    // We show kDisplayRangeHours total starting from index 0
    final endIndex = kDisplayRangeHours.clamp(0, hourly.length);
    return hourly.sublist(0, endIndex);
  }

  /// Get the index of "now" in the display data.
  /// Finds the hour slot matching current time by comparing timestamps.
  ///
  /// Timezone note: The API returns timestamps without timezone offsets
  /// (e.g., "2024-01-15T12:00:00"), which DateTime.parse() interprets as
  /// device local time. Since DateTime.now() is also device local time,
  /// the comparison is consistent. This works correctly when the device
  /// timezone matches the weather location (typical for GPS-based weather).
  /// Edge case: if the user travels to a new timezone and the phone updates
  /// but cached weather data remains, hours may be off until data refreshes.
  int getNowIndex() {
    final now = DateTime.now();
    // Truncate to hour precision for comparison
    final nowHour = DateTime(now.year, now.month, now.day, now.hour);

    // Find the hour slot that matches current time
    for (var i = 0; i < hourly.length; i++) {
      final entryHour = DateTime(
        hourly[i].time.year,
        hourly[i].time.month,
        hourly[i].time.day,
        hourly[i].time.hour,
      );
      if (entryHour == nowHour) {
        return i;
      }
    }

    // Fallback: find closest hour before now
    for (var i = hourly.length - 1; i >= 0; i--) {
      if (hourly[i].time.isBefore(now)) {
        return i;
      }
    }

    // Ultimate fallback
    return kPastHours.clamp(0, hourly.length - 1);
  }

  /// Find the current hour's data.
  HourlyData? getCurrentHour() {
    final idx = getNowIndex();
    if (idx >= 0 && idx < hourly.length) {
      return hourly[idx];
    }
    return null;
  }
}

/// Single hour of weather data.
class HourlyData {
  final DateTime time;

  /// Temperature in Celsius.
  final double temperature;

  /// Precipitation in mm.
  final double precipitation;

  /// Cloud cover percentage (0-100).
  final int cloudCover;

  HourlyData({
    required this.time,
    required this.temperature,
    required this.precipitation,
    required this.cloudCover,
  });

  /// Convert temperature to Fahrenheit.
  double get temperatureFahrenheit => temperature * 9 / 5 + 32;

  /// Convert precipitation to inches.
  double get precipitationInches => precipitation / 25.4;
}
