import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteogram_widget/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('light theme has correct brightness', () {
      final theme = AppTheme.light();
      expect(theme.brightness, Brightness.light);
    });

    test('dark theme has correct brightness', () {
      final theme = AppTheme.dark();
      expect(theme.brightness, Brightness.dark);
    });

    test('light theme uses Material 3', () {
      final theme = AppTheme.light();
      expect(theme.useMaterial3, isTrue);
    });

    test('dark theme uses Material 3', () {
      final theme = AppTheme.dark();
      expect(theme.useMaterial3, isTrue);
    });

    test('light theme accepts dynamic color scheme', () {
      final dynamicScheme = ColorScheme.fromSeed(
        seedColor: Colors.purple,
        brightness: Brightness.light,
      );
      final theme = AppTheme.light(dynamicScheme);
      expect(theme.colorScheme.primary, dynamicScheme.primary);
    });

    test('dark theme accepts dynamic color scheme', () {
      final dynamicScheme = ColorScheme.fromSeed(
        seedColor: Colors.purple,
        brightness: Brightness.dark,
      );
      final theme = AppTheme.dark(dynamicScheme);
      expect(theme.colorScheme.primary, dynamicScheme.primary);
    });
  });

  group('MeteogramColors presets', () {
    test('light preset has white card background', () {
      expect(MeteogramColors.light.cardBackground, const Color(0xFFFFFFFF));
    });

    test('dark preset has dark card background', () {
      expect(MeteogramColors.dark.cardBackground, const Color(0xFF1B2838));
    });

    test('light preset has coral temperature line', () {
      expect(MeteogramColors.light.temperatureLine, const Color(0xFFFF6B6B));
    });

    test('dark preset has lighter coral temperature line', () {
      expect(MeteogramColors.dark.temperatureLine, const Color(0xFFFF7675));
    });

    test('light preset has teal precipitation bar', () {
      expect(MeteogramColors.light.precipitationBar, const Color(0xFF4ECDC4));
    });

    test('dark preset has cyan precipitation bar', () {
      expect(MeteogramColors.dark.precipitationBar, const Color(0xFF00CEC9));
    });
  });

  group('MeteogramColors.getSkyColor', () {
    test('returns clear sky color for 0% cloud cover', () {
      final color = MeteogramColors.light.getSkyColor(0);
      expect(color, MeteogramColors.light.clearSky);
    });

    test('returns partly cloudy for 30% cloud cover', () {
      final color = MeteogramColors.light.getSkyColor(30);
      expect(color, MeteogramColors.light.partlyCloudySky);
    });

    test('returns overcast for 100% cloud cover', () {
      final color = MeteogramColors.light.getSkyColor(100);
      expect(color, MeteogramColors.light.overcastSky);
    });

    test('interpolates between clear and partly cloudy (15%)', () {
      final color = MeteogramColors.light.getSkyColor(15);
      // Should be halfway between clear and partly cloudy
      final expected = Color.lerp(
        MeteogramColors.light.clearSky,
        MeteogramColors.light.partlyCloudySky,
        0.5,
      );
      expect(color, expected);
    });

    test('interpolates between partly cloudy and overcast (65%)', () {
      final color = MeteogramColors.light.getSkyColor(65);
      // (65 - 30) / 70 = 0.5
      final expected = Color.lerp(
        MeteogramColors.light.partlyCloudySky,
        MeteogramColors.light.overcastSky,
        0.5,
      );
      expect(color, expected);
    });

    test('works with dark theme colors', () {
      final clearColor = MeteogramColors.dark.getSkyColor(0);
      final overcastColor = MeteogramColors.dark.getSkyColor(100);

      expect(clearColor, MeteogramColors.dark.clearSky);
      expect(overcastColor, MeteogramColors.dark.overcastSky);
    });
  });

  group('MeteogramColors.copyWith', () {
    test('copies with new background', () {
      const newBg = Color(0xFF123456);
      final copied = MeteogramColors.light.copyWith(background: newBg);

      expect(copied.background, newBg);
      expect(copied.cardBackground, MeteogramColors.light.cardBackground);
      expect(copied.temperatureLine, MeteogramColors.light.temperatureLine);
    });

    test('copies with new temperature line', () {
      const newTemp = Color(0xFF654321);
      final copied = MeteogramColors.light.copyWith(temperatureLine: newTemp);

      expect(copied.temperatureLine, newTemp);
      expect(copied.background, MeteogramColors.light.background);
    });

    test('copies with new temperature gradients', () {
      const newStart = Color(0x80123456);
      const newEnd = Color(0x00123456);
      final copied = MeteogramColors.light.copyWith(
        temperatureGradientStart: newStart,
        temperatureGradientEnd: newEnd,
      );

      expect(copied.temperatureGradientStart, newStart);
      expect(copied.temperatureGradientEnd, newEnd);
    });

    test('copies with new time label', () {
      const newLabel = Color(0xFFABCDEF);
      final copied = MeteogramColors.light.copyWith(timeLabel: newLabel);

      expect(copied.timeLabel, newLabel);
    });

    test('preserves all other colors', () {
      final copied = MeteogramColors.light.copyWith(background: Colors.red);

      expect(copied.precipitationBar, MeteogramColors.light.precipitationBar);
      expect(copied.nowIndicator, MeteogramColors.light.nowIndicator);
      expect(copied.gridLine, MeteogramColors.light.gridLine);
      expect(copied.labelText, MeteogramColors.light.labelText);
      expect(copied.primaryText, MeteogramColors.light.primaryText);
      expect(copied.clearSky, MeteogramColors.light.clearSky);
      expect(copied.sunshineBar, MeteogramColors.light.sunshineBar);
    });
  });

  group('MeteogramColors.fromColorScheme', () {
    test('light mode uses onPrimaryContainer for temperature', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      );
      final colors = MeteogramColors.fromColorScheme(scheme, isDark: false);

      expect(colors.temperatureLine, scheme.onPrimaryContainer);
    });

    test('dark mode uses primary for temperature', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      );
      final colors = MeteogramColors.fromColorScheme(scheme, isDark: true);

      expect(colors.temperatureLine, scheme.primary);
    });

    test('uses surface for background', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.light,
      );
      final colors = MeteogramColors.fromColorScheme(scheme, isDark: false);

      expect(colors.background, scheme.surface);
    });

    test('uses tertiary for time label', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.orange,
        brightness: Brightness.light,
      );
      final colors = MeteogramColors.fromColorScheme(scheme, isDark: false);

      expect(colors.timeLabel, scheme.tertiary);
    });

    test('light mode gradient has 0x40 alpha', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.red,
        brightness: Brightness.light,
      );
      final colors = MeteogramColors.fromColorScheme(scheme, isDark: false);

      expect((colors.temperatureGradientStart.a * 255).round(), 0x40);
      expect((colors.temperatureGradientEnd.a * 255).round(), 0x00);
    });

    test('dark mode gradient has 0x60 alpha', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.red,
        brightness: Brightness.dark,
      );
      final colors = MeteogramColors.fromColorScheme(scheme, isDark: true);

      expect((colors.temperatureGradientStart.a * 255).round(), 0x60);
      expect((colors.temperatureGradientEnd.a * 255).round(), 0x00);
    });

    test('preserves base preset colors', () {
      final scheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      );
      final colors = MeteogramColors.fromColorScheme(scheme, isDark: false);

      // These should come from the light preset
      expect(colors.precipitationBar, MeteogramColors.light.precipitationBar);
      expect(colors.nowIndicator, MeteogramColors.light.nowIndicator);
      expect(colors.clearSky, MeteogramColors.light.clearSky);
    });
  });

  group('WeatherGradients', () {
    test('clearDay has blue colors', () {
      expect(WeatherGradients.clearDay.colors.first, const Color(0xFF74B9FF));
      expect(WeatherGradients.clearDay.colors.last, const Color(0xFF0984E3));
    });

    test('clearNight has dark colors', () {
      expect(WeatherGradients.clearNight.colors.first, const Color(0xFF2D3436));
      expect(WeatherGradients.clearNight.colors.last, const Color(0xFF0D1B2A));
    });

    test('cloudy has gray colors', () {
      expect(WeatherGradients.cloudy.colors.first, const Color(0xFF636E72));
    });

    test('rainy has dark gray colors', () {
      expect(WeatherGradients.rainy.colors.first, const Color(0xFF4A5568));
    });

    test('all gradients have topLeft to bottomRight alignment', () {
      expect(WeatherGradients.clearDay.begin, Alignment.topLeft);
      expect(WeatherGradients.clearDay.end, Alignment.bottomRight);
      expect(WeatherGradients.clearNight.begin, Alignment.topLeft);
      expect(WeatherGradients.cloudy.begin, Alignment.topLeft);
      expect(WeatherGradients.rainy.begin, Alignment.topLeft);
    });
  });

  group('WeatherGradients.forConditions', () {
    test('returns rainy for high precipitation', () {
      final gradient = WeatherGradients.forConditions(
        cloudCover: 0,
        precipitation: 1.0,
        isDaytime: true,
      );
      expect(gradient, WeatherGradients.rainy);
    });

    test('returns rainy for precipitation > 0.5', () {
      final gradient = WeatherGradients.forConditions(
        cloudCover: 0,
        precipitation: 0.6,
        isDaytime: true,
      );
      expect(gradient, WeatherGradients.rainy);
    });

    test('returns cloudy for high cloud cover', () {
      final gradient = WeatherGradients.forConditions(
        cloudCover: 80,
        precipitation: 0.0,
        isDaytime: true,
      );
      expect(gradient, WeatherGradients.cloudy);
    });

    test('returns cloudy for cloud cover > 60', () {
      final gradient = WeatherGradients.forConditions(
        cloudCover: 61,
        precipitation: 0.0,
        isDaytime: true,
      );
      expect(gradient, WeatherGradients.cloudy);
    });

    test('returns clearDay for clear daytime', () {
      final gradient = WeatherGradients.forConditions(
        cloudCover: 30,
        precipitation: 0.0,
        isDaytime: true,
      );
      expect(gradient, WeatherGradients.clearDay);
    });

    test('returns clearNight for clear nighttime', () {
      final gradient = WeatherGradients.forConditions(
        cloudCover: 30,
        precipitation: 0.0,
        isDaytime: false,
      );
      expect(gradient, WeatherGradients.clearNight);
    });

    test('precipitation takes priority over cloud cover', () {
      // Even with 0% cloud cover, high precipitation = rainy
      final gradient = WeatherGradients.forConditions(
        cloudCover: 0,
        precipitation: 1.0,
        isDaytime: true,
      );
      expect(gradient, WeatherGradients.rainy);
    });

    test('cloud cover takes priority over time of day', () {
      // High cloud cover = cloudy regardless of day/night
      final gradientDay = WeatherGradients.forConditions(
        cloudCover: 80,
        precipitation: 0.0,
        isDaytime: true,
      );
      final gradientNight = WeatherGradients.forConditions(
        cloudCover: 80,
        precipitation: 0.0,
        isDaytime: false,
      );
      expect(gradientDay, WeatherGradients.cloudy);
      expect(gradientNight, WeatherGradients.cloudy);
    });
  });
}
