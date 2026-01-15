// Application-wide constants.
// Centralizes magic numbers and configuration values for maintainability.

/// How long weather data remains valid before being considered stale.
/// Used by foreground refresh timer and background service.
const Duration kWeatherStalenessThreshold = Duration(minutes: 15);

/// How often the foreground app checks for stale data and hour boundaries.
const Duration kForegroundRefreshInterval = Duration(minutes: 1);

/// Chart visual constants for SVG generation.
class ChartConstants {
  /// Time label font size as ratio of chart width (4% of width).
  static const double timeFontSizeRatio = 0.04;

  /// Temperature label font size as ratio of chart width (4.5% of width).
  static const double tempFontSizeRatio = 0.045;

  /// Bar width as ratio of slot width (70% of available space).
  static const double barWidthRatio = 0.7;

  /// Chart height as percentage of total height (95%).
  static const double chartHeightRatio = 0.95;

  /// Temperature range vertical padding (10% of range).
  static const double tempRangePaddingRatio = 0.10;

  /// Opacity for daylight bars.
  static const double daylightBarOpacity = 0.8;

  /// Opacity for precipitation bars.
  static const double precipitationBarOpacity = 0.85;
}

/// Half-hour alarm timing constants.
/// The "now" indicator snaps to nearest hour at :30, so alarms fire then.
class AlarmConstants {
  /// Buffer after half-hour boundary to ensure alarm fires after :30 (seconds).
  static const int halfHourBoundaryBufferSeconds = 15;

  /// Minute threshold for "now" indicator rounding (>= this rounds up to next hour).
  static const int nowIndicatorRoundingMinute = 30;
}
