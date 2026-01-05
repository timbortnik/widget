/// Hours of past data to request from API.
const int kPastHours = 6;

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
      fetchedAt: json['fetchedAt'] != null
          ? DateTime.parse(json['fetchedAt'] as String)
          : DateTime.now(),
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

  /// Get data for display range: past hours + ~46h future.
  /// Returns a slice of hourly data centered on "now".
  List<HourlyData> getDisplayRange() {
    // API returns: kPastHours + forecast_days (2) * 24 hours
    // We show 52 hours total starting from index 0
    final endIndex = (kPastHours + 46).clamp(0, hourly.length);
    return hourly.sublist(0, endIndex);
  }

  /// Get the index of "now" in the display data.
  /// Accounts for data age - if data is X hours old, shifts index forward by X.
  int getNowIndex() {
    final hoursOld = DateTime.now().difference(fetchedAt).inHours;
    final adjustedIndex = kPastHours + hoursOld;
    return adjustedIndex.clamp(0, hourly.length - 1);
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
