import 'package:flutter/painting.dart';

import '../theme/app_theme.dart';
import 'widget_store.dart';

/// A chart colour scheme the user can pick for the meteogram.
///
/// The scheme is orthogonal to the light/dark theme: every scheme defines both
/// variants natively, so choosing one never overrides the theme choice. The
/// chart is affected, plus — for the fixed schemes — the card it sits on and
/// that card's header; all other app chrome stays on Material You.
///
/// [id] is the wire value shared with Kotlin; it must stay in sync with
/// `ChartSchemes` (`ChartSchemes.kt`), which resolves it during rendering.
enum ChartScheme {
  /// Material You on Android 12+, built-in presets below it.
  defaultScheme('default'),

  /// Polar day and dusk: low apricot sun, ice-blue cold, snow.
  thermal('thermal'),

  /// Maximum-contrast palette: pure black/white grounds, widened strokes.
  highContrast('contrast');

  const ChartScheme(this.id);

  /// Value persisted in the shared store and read by the native renderer.
  final String id;

  /// Absolute temperature colour scale as (°C, colour) stops, ascending, or
  /// null when the scheme draws temperature in a single colour. Mirrors
  /// `temperatureScale` in `ChartSchemes.kt`; the two must change together.
  List<(double, Color)>? temperatureScale({required bool isDark}) {
    if (this != thermal) return null;
    return isDark
        ? const [
            (-20.0, Color(0xFFB8A8F0)),
            (0.0, Color(0xFF8FC9E0)),
            (20.0, Color(0xFFD8D4DC)),
            (40.0, Color(0xFFF2708A)),
          ]
        : const [
            (-20.0, Color(0xFF3B3A8F)),
            (0.0, Color(0xFF1A6684)),
            (20.0, Color(0xFF52586A)),
            (40.0, Color(0xFFB8305F)),
          ];
  }

  /// Colour for [celsius] on [temperatureScale], interpolated per channel as
  /// the chart's SVG gradient does and clamped at both ends; null when the
  /// scheme has no scale.
  Color? temperatureColor(double celsius, {required bool isDark}) =>
      _colorOnScale(temperatureScale(isDark: isDark), celsius);

  /// Absolute scale colouring the daylight bars (and the legend's sun) by
  /// temperature, as (°C, colour) stops; null when the sun has one colour.
  /// Mirrors `daylightScale` in `ChartSchemes.kt`.
  List<(double, Color)>? daylightScale({required bool isDark}) {
    if (this != thermal) return null;
    return isDark
        ? const [(-20.0, Color(0xFFE09060)), (40.0, Color(0xFFF2D45C))]
        : const [(-20.0, Color(0xFFD9864F)), (40.0, Color(0xFFFF8F00))];
  }

  /// Scale moving the card ground with the current temperature, as (°C,
  /// colour) stops; null when the ground is fixed. Mirrors
  /// `groundScale` in `ChartSchemes.kt`.
  List<(double, Color)>? groundScale({required bool isDark}) {
    if (this != thermal) return null;
    return isDark
        ? const [(-20.0, Color(0xFF2E1D22)), (40.0, Color(0xFF1F1D33))]
        : const [(-20.0, Color(0xFFF1E7EE)), (40.0, Color(0xFFE4ECF4))];
  }

  /// Card ground for the current [celsius]; null keeps the fixed card colour.
  Color? groundColor(double celsius, {required bool isDark}) =>
      _colorOnScale(groundScale(isDark: isDark), celsius);

  /// Sun colour for [celsius] on [daylightScale]; null without a scale.
  Color? daylightColor(double celsius, {required bool isDark}) =>
      _colorOnScale(daylightScale(isDark: isDark), celsius);

  static Color? _colorOnScale(List<(double, Color)>? scale, double celsius) {
    if (scale == null) return null;
    if (celsius <= scale.first.$1) return scale.first.$2;
    if (celsius >= scale.last.$1) return scale.last.$2;
    final upper = scale.indexWhere((stop) => stop.$1 >= celsius);
    final (t0, c0) = scale[upper - 1];
    final (t1, c1) = scale[upper];
    return Color.lerp(c0, c1, (celsius - t0) / (t1 - t0));
  }

  /// Colour for snow when the scheme splits precipitation by phase (rain
  /// then takes `precipitationBar`), or null when all precipitation shares
  /// one colour. Mirrors `snowBar` in `ChartSchemes.kt`.
  Color? snowColor({required bool isDark}) {
    if (this != thermal) return null;
    return isDark ? const Color(0xFFEEF3F7) : const Color(0xFF7A8AA0);
  }

  /// Colours for the weather card (background, big temperature, legend),
  /// derived from the Material You [base].
  ///
  /// [defaultScheme] keeps them. The fixed schemes are tuned for their own
  /// ground and paint it into the chart, so the card must match, and the
  /// header must echo the chart — temperature like the line, legend icons in
  /// the bar colours. Mirrors the palettes in `ChartSchemes.kt`; the two must
  /// change together.
  MeteogramColors cardColors(MeteogramColors base, {required bool isDark}) {
    switch (this) {
      case defaultScheme:
        return base;
      case thermal:
        return base.copyWith(
          cardBackground: isDark ? const Color(0xFF2A1D2E) : const Color(0xFFE7E9F4),
          temperatureLine: isDark ? const Color(0xFF8FC9E0) : const Color(0xFF1A6684),
          primaryText: isDark ? const Color(0xFFECEFF4) : const Color(0xFF2E3440),
          daylightIcon: isDark ? const Color(0xFFE09060) : const Color(0xFFD9864F),
          precipitationBar: isDark ? const Color(0xFF5B8DEF) : const Color(0xFF2F5FC0),
        );
      case highContrast:
        const white = Color(0xFFFFFFFF);
        const black = Color(0xFF000000);
        return base.copyWith(
          cardBackground: isDark ? black : white,
          temperatureLine: isDark ? white : black,
          primaryText: isDark ? white : black,
          daylightIcon: isDark ? const Color(0xFFE6B84A) : const Color(0xFFC87000),
          precipitationBar: isDark ? const Color(0xFF4FC3F7) : const Color(0xFF0B4FA8),
        );
    }
  }
}

/// Persists the user's chart colour scheme choice.
///
/// The choice drives both the in-app chart and the home-screen widget, which
/// are rendered by the same native code, so it is stored in [WidgetStore]
/// (`HomeWidgetPreferences`) — the same store the native renderer reads.
class SchemeService {
  /// Storage key holding the serialized [ChartScheme].
  static const String _prefKey = 'color_scheme';

  /// Loads the saved scheme, defaulting to [ChartScheme.defaultScheme].
  Future<ChartScheme> load() async {
    return fromId(await WidgetStore.getWidgetData<String>(_prefKey));
  }

  /// Persists [scheme] for future launches in the shared widget store.
  Future<void> save(ChartScheme scheme) async {
    await WidgetStore.saveWidgetData<String>(_prefKey, scheme.id);
  }

  /// Maps a stored id back to a scheme, falling back to the default for null
  /// or unrecognized values (e.g. a pref written by a newer version).
  static ChartScheme fromId(String? id) {
    for (final scheme in ChartScheme.values) {
      if (scheme.id == id) return scheme;
    }
    return ChartScheme.defaultScheme;
  }
}
