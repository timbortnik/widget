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
    final times = hourlyJson['time'] as List;
    final temperatures = hourlyJson['temperature_2m'] as List;
    final precipitation = hourlyJson['precipitation'] as List;
    final cloudCover = hourlyJson['cloud_cover'] as List;

    // Validate array lengths match to prevent index errors
    final minLength = [times.length, temperatures.length, precipitation.length, cloudCover.length]
        .reduce((a, b) => a < b ? a : b);

    final hourlyData = <HourlyData>[];
    for (var i = 0; i < minLength; i++) {
      // Skip entries with null values
      if (times[i] == null || temperatures[i] == null) continue;

      // Parse timestamp as UTC (API returns UTC timestamps)
      final timeStr = times[i] as String;
      final timeUtc = DateTime.parse(timeStr.endsWith('Z') ? timeStr : '${timeStr}Z');

      hourlyData.add(HourlyData(
        time: timeUtc,
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
  /// Snaps to the nearest hour (rounds at 30 minutes) for visual cleanliness.
  int getNowIndex() {
    final nowUtc = DateTime.now().toUtc();
    // Round to nearest hour: if minute >= 30, use next hour
    final roundedHour = nowUtc.minute >= 30
        ? DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, nowUtc.hour + 1)
        : DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, nowUtc.hour);

    // Find the hour slot that matches rounded time
    for (var i = 0; i < hourly.length; i++) {
      final entryHour = DateTime.utc(
        hourly[i].time.year,
        hourly[i].time.month,
        hourly[i].time.day,
        hourly[i].time.hour,
      );
      if (entryHour == roundedHour) {
        return i;
      }
    }

    // Fallback: find closest hour before now
    for (var i = hourly.length - 1; i >= 0; i--) {
      if (hourly[i].time.isBefore(nowUtc)) {
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
