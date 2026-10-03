import 'package:flutter/painting.dart';

import '../theme/app_theme.dart';
import 'widget_store.dart';

/// A chart colour scheme the user can pick for the meteogram.
///
/// The scheme is orthogonal to the light/dark theme: every scheme defines both
/// variants natively, so choosing one never overrides the theme choice. The
/// chart is affected, plus — for [highContrast] only — the card it sits on
/// and that card's header; all other app chrome stays on Material You.
///
/// [id] is the wire value shared with Kotlin; it must stay in sync with
/// `ChartSchemes` (`ChartSchemes.kt`), which resolves it during rendering.
enum ChartScheme {
  /// Material You on Android 12+, built-in presets below it.
  defaultScheme('default'),

  /// Cool, muted arctic palette.
  arctic('arctic'),

  /// Maximum-contrast palette: pure black/white grounds, widened strokes.
  highContrast('contrast');

  const ChartScheme(this.id);

  /// Value persisted in the shared store and read by the native renderer.
  final String id;

  /// Colours for the weather card (background, big temperature, legend),
  /// derived from the Material You [base].
  ///
  /// Only [highContrast] overrides them: its chart is tuned for pure
  /// white/black and paints that ground itself, so the card must match, and
  /// the header must echo the chart — temperature in ink like the line, legend
  /// icons in the bar colours. Mirrors `contrastLight`/`contrastDark` in
  /// `ChartSchemes.kt`; the two must change together.
  MeteogramColors cardColors(MeteogramColors base, {required bool isDark}) {
    if (this != highContrast) return base;
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
