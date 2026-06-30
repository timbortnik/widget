/// Stable accessibility identifiers for interactive UI elements.
///
/// Each value is passed to `Semantics(identifier: ...)`, which the Flutter
/// engine surfaces to Android as the node's `resource-id`
/// (`AccessibilityBridge.setViewIdResourceName`). Black-box UI tests
/// (Appium + UiAutomator2) locate elements by these exact strings, so they are
/// a stable, locale-independent contract — unlike visible text, which is
/// localized across 30+ languages.
///
/// IMPORTANT: these strings are mirrored verbatim in the test harness
/// (`e2e/a11y_ids.js`). The test never imports Flutter; the string values are
/// the only shared contract. Do not rename a value without updating that file.
class A11yIds {
  A11yIds._();

  // Home screen
  static const String homeRetryButton = 'home_retry_button';
  static const String homeThemeButton = 'home_theme_button';
  static const String homeLocationSelector = 'home_location_selector';
  static const String homeOpenMeteoLink = 'home_open_meteo_link';
  static const String homeGithubLink = 'home_github_link';
  // The hourly/weekly charts are plain Flutter `Image` widgets (PNG rasterized
  // natively), so a normal `Semantics` reaches them: they carry both a
  // resource-id (below) and a localized content-desc label. Tests can locate
  // them by either.
  static const String homeHourlyChart = 'home_hourly_chart';
  static const String homeWeeklyChart = 'home_weekly_chart';

  // Location picker sheet
  static const String locationSearchField = 'location_search_field';
  static const String locationClearSearch = 'location_clear_search';
  static const String locationGpsTile = 'location_gps_tile';

  /// Dynamic search-result tiles are suffixed with their index, e.g.
  /// `location_result_tile_0`.
  static const String locationResultTilePrefix = 'location_result_tile';

  /// Dynamic recent-city tiles are suffixed with their index, e.g.
  /// `location_recent_tile_0`.
  static const String locationRecentTilePrefix = 'location_recent_tile';

  // Theme picker sheet
  static const String themeOptionSystem = 'theme_option_system';
  static const String themeOptionLight = 'theme_option_light';
  static const String themeOptionDark = 'theme_option_dark';
}
