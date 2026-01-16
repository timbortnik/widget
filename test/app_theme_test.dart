import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteogram_widget/services/material_you_service.dart';
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

    test('light theme accepts native Material You colors', () {
      const nativeColors = MaterialYouThemeColors(
        primary: Colors.purple,
        onPrimaryContainer: Colors.deepPurple,
        tertiary: Colors.teal,
        surface: Colors.white,
        surfaceContainer: Color(0xFFEEEEEE),
        surfaceContainerHigh: Color(0xFFE0E0E0),
        onSurface: Colors.black,
      );
      final theme = AppTheme.light(nativeColors);
      expect(theme.colorScheme.primary, nativeColors.primary);
    });

    test('dark theme accepts native Material You colors', () {
      const nativeColors = MaterialYouThemeColors(
        primary: Colors.purpleAccent,
        onPrimaryContainer: Colors.purple,
        tertiary: Colors.tealAccent,
        surface: Color(0xFF121212),
        surfaceContainer: Color(0xFF1E1E1E),
        surfaceContainerHigh: Color(0xFF2D2D2D),
        onSurface: Colors.white,
      );
      final theme = AppTheme.dark(nativeColors);
      expect(theme.colorScheme.primary, nativeColors.primary);
    });
  });

  group('MeteogramColors presets', () {
    test('light preset has white card background', () {
      expect(MeteogramColors.light.cardBackground, const Color(0xFFFFFFFF));
    });

    test('dark preset has dark card background', () {
      expect(MeteogramColors.dark.cardBackground, const Color(0xFF2D2D2D));
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
      expect(copied.daylightBar, MeteogramColors.light.daylightBar);
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
    });
  });
}
