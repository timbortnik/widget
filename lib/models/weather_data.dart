/// Weather data model for Open-Meteo API response.
class WeatherData {
  final String timezone;
  final List<HourlyData> hourly;
  final DateTime fetchedAt;

  WeatherData({
    required this.timezone,
    required this.hourly,
    required this.fetchedAt,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final hourlyJson = json['hourly'] as Map<String, dynamic>;
    final times = (hourlyJson['time'] as List);
    final temperatures = (hourlyJson['temperature_2m'] as List);
    final precipitation = (hourlyJson['precipitation'] as List);
    final cloudCover = (hourlyJson['cloud_cover'] as List);

    final hourlyData = <HourlyData>[];
    for (var i = 0; i < times.length; i++) {
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
      hourly: hourlyData,
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'timezone': timezone,
        'fetchedAt': fetchedAt.toIso8601String(),
        'hourly': {
          'time': hourly.map((h) => h.time.toIso8601String()).toList(),
          'temperature_2m': hourly.map((h) => h.temperature).toList(),
          'precipitation': hourly.map((h) => h.precipitation).toList(),
          'cloud_cover': hourly.map((h) => h.cloudCover).toList(),
        },
      };

  /// Get data for display range: 8h past to ~44h future.
  /// Returns a slice of hourly data centered on "now".
  /// Since we request past_hours=8, index 8 in the raw data is "now".
  List<HourlyData> getDisplayRange() {
    // API returns: past_hours (8) + forecast_days (2) * 24 = 56 hours
    // We want to show: 8h past + 44h future = 52 hours starting from index 0
    final endIndex = (8 + 44).clamp(0, hourly.length);
    return hourly.sublist(0, endIndex);
  }

  /// Get the index of "now" in the display data.
  /// Since we request past_hours=8, the current hour is at index 8.
  int getNowIndex() {
    return 8.clamp(0, hourly.length - 1);
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
