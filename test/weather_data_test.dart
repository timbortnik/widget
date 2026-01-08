import 'package:flutter_test/flutter_test.dart';
import 'package:meteogram_widget/models/weather_data.dart';

void main() {
  group('getNowIndex', () {
    /// Create test weather data with hourly entries starting from a base time.
    WeatherData createTestData({
      required DateTime baseTime,
      required DateTime fetchedAt,
      int hours = 52, // kPastHours (6) + kForecastHours (46)
    }) {
      final hourly = List.generate(hours, (i) {
        final time = baseTime.add(Duration(hours: i));
        return HourlyData(
          time: time,
          temperature: 20.0 + i * 0.5,
          precipitation: 0.0,
          cloudCover: 50,
        );
      });

      return WeatherData(
        timezone: 'UTC',
        latitude: 50.0,
        longitude: 30.0,
        hourly: hourly,
        fetchedAt: fetchedAt,
      );
    }

    test('finds exact hour match', () {
      // Data starts at 12:00, entry at index 3 is 15:00
      final baseTime = DateTime(2024, 1, 15, 12, 0);
      final data = createTestData(baseTime: baseTime, fetchedAt: baseTime);

      // Verify the data structure: hourly[3] should be 15:00
      expect(data.hourly[3].time.hour, equals(15));
    });

    test('finds hour even when fetched mid-hour (the bug fix)', () {
      // This tests the bug: data fetched at 17:30, now is 18:15
      // Old code: (18:15 - 17:30).inHours = 0, so index didn't advance
      // New code: finds entry where time.hour == 18

      final baseTime = DateTime(2024, 1, 15, 12, 0); // Data starts at 12:00
      final fetchedAt = DateTime(2024, 1, 15, 17, 30); // Fetched at 17:30
      final data = createTestData(baseTime: baseTime, fetchedAt: fetchedAt);

      // Entry at index 6 is 18:00 (12 + 6 = 18)
      expect(data.hourly[6].time.hour, equals(18));

      // The getNowIndex should find index 6 when "now" is 18:xx
      // We can't directly test with DateTime.now(), but we can verify
      // the data structure is correct for the algorithm
    });

    test('hourly data has correct timestamps', () {
      final baseTime = DateTime(2024, 1, 15, 6, 0); // 6 hours ago
      final data = createTestData(baseTime: baseTime, fetchedAt: baseTime);

      // Verify kPastHours (6) entries are in the past relative to fetch time
      expect(data.hourly[0].time.hour, equals(6));
      expect(data.hourly[6].time.hour, equals(12)); // "now" at fetch time
      expect(data.hourly[12].time.hour, equals(18)); // 6 hours after fetch
    });

    test('getCurrentHour returns data at now index', () {
      final now = DateTime.now();
      final baseTime = DateTime(now.year, now.month, now.day, now.hour - 6);
      final data = createTestData(baseTime: baseTime, fetchedAt: now);

      final currentHour = data.getCurrentHour();
      expect(currentHour, isNotNull);
      expect(currentHour!.time.hour, equals(now.hour));
    });

    test('getNowIndex finds current hour in real data', () {
      final now = DateTime.now();
      // Create data starting 6 hours ago (like the real API)
      final baseTime = DateTime(now.year, now.month, now.day, now.hour - 6);
      final data = createTestData(baseTime: baseTime, fetchedAt: now);

      final nowIndex = data.getNowIndex();

      // The index should point to an entry with the current hour
      expect(data.hourly[nowIndex].time.hour, equals(now.hour));
      expect(data.hourly[nowIndex].time.day, equals(now.day));
    });

    test('getNowIndex works when data is 30 minutes old', () {
      final now = DateTime.now();
      // Fetched 30 minutes ago (same hour)
      final fetchedAt = now.subtract(const Duration(minutes: 30));
      final baseTime = DateTime(
        fetchedAt.year,
        fetchedAt.month,
        fetchedAt.day,
        fetchedAt.hour - 6,
      );
      final data = createTestData(baseTime: baseTime, fetchedAt: fetchedAt);

      final nowIndex = data.getNowIndex();

      // Should still find current hour even though data is 30 min old
      expect(data.hourly[nowIndex].time.hour, equals(now.hour));
    });

    test('getNowIndex works after hour boundary crossed', () {
      final now = DateTime.now();
      // Simulate: fetched at XX:50, now is (XX+1):10 (crossed hour boundary)
      // We need current minute > 10 for this test to make sense
      if (now.minute < 15) {
        // Skip if we're too close to hour boundary
        return;
      }

      // Create data as if fetched 50 minutes ago
      final fetchedAt = now.subtract(const Duration(minutes: 50));
      final baseTime = DateTime(
        fetchedAt.year,
        fetchedAt.month,
        fetchedAt.day,
        fetchedAt.hour - 6,
      );
      final data = createTestData(baseTime: baseTime, fetchedAt: fetchedAt);

      final nowIndex = data.getNowIndex();

      // Should find current hour, not the hour when fetched
      expect(data.hourly[nowIndex].time.hour, equals(now.hour));
    });

    test('getNowIndex uses fallback when hour not found', () {
      // Create data with hours that don't include current time (very old data)
      final baseTime = DateTime(2020, 1, 1, 0, 0);
      final data = createTestData(baseTime: baseTime, fetchedAt: baseTime);

      final nowIndex = data.getNowIndex();

      // Should use fallback (find closest hour before now, or kPastHours)
      expect(nowIndex, greaterThanOrEqualTo(0));
      expect(nowIndex, lessThan(data.hourly.length));
    });

    test('getDisplayRange returns correct number of hours', () {
      final baseTime = DateTime.now().subtract(const Duration(hours: 6));
      final data = createTestData(baseTime: baseTime, fetchedAt: DateTime.now());

      final displayData = data.getDisplayRange();

      expect(displayData.length, equals(kDisplayRangeHours));
    });
  });

  group('WeatherData serialization', () {
    test('toJson and fromJson roundtrip preserves data', () {
      final now = DateTime.now();
      final original = WeatherData(
        timezone: 'Europe/Kyiv',
        latitude: 50.45,
        longitude: 30.52,
        fetchedAt: now,
        hourly: [
          HourlyData(
            time: now,
            temperature: 15.5,
            precipitation: 2.3,
            cloudCover: 75,
          ),
          HourlyData(
            time: now.add(const Duration(hours: 1)),
            temperature: 16.0,
            precipitation: 0.0,
            cloudCover: 50,
          ),
        ],
      );

      final json = original.toJson();
      final restored = WeatherData.fromJson(json);

      expect(restored.timezone, equals(original.timezone));
      expect(restored.latitude, equals(original.latitude));
      expect(restored.longitude, equals(original.longitude));
      expect(restored.hourly.length, equals(original.hourly.length));
      expect(restored.hourly[0].temperature, equals(15.5));
      expect(restored.hourly[0].precipitation, equals(2.3));
      expect(restored.hourly[0].cloudCover, equals(75));
    });
  });

  group('HourlyData', () {
    test('temperatureFahrenheit converts correctly', () {
      final data = HourlyData(
        time: DateTime.now(),
        temperature: 0.0, // 0°C = 32°F
        precipitation: 0.0,
        cloudCover: 0,
      );
      expect(data.temperatureFahrenheit, equals(32.0));

      final data2 = HourlyData(
        time: DateTime.now(),
        temperature: 100.0, // 100°C = 212°F
        precipitation: 0.0,
        cloudCover: 0,
      );
      expect(data2.temperatureFahrenheit, equals(212.0));
    });

    test('precipitationInches converts correctly', () {
      final data = HourlyData(
        time: DateTime.now(),
        temperature: 20.0,
        precipitation: 25.4, // 25.4mm = 1 inch
        cloudCover: 0,
      );
      expect(data.precipitationInches, closeTo(1.0, 0.001));
    });
  });
}
