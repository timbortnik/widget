// Mirror of lib/a11y_ids.dart — these string values are the contract between
// the Flutter app (Semantics identifier -> Android resource-id) and these
// black-box tests. The test harness imports NO Flutter; keep this in sync by
// hand. Do not rename a value without updating lib/a11y_ids.dart.
module.exports = {
  // Home screen
  homeRetryButton: 'home_retry_button',
  homeThemeButton: 'home_theme_button',
  homeLocationSelector: 'home_location_selector',
  homeOpenMeteoLink: 'home_open_meteo_link',
  homeGithubLink: 'home_github_link',
  // Charts are hybrid-composition PlatformViews with no resource-id; they carry
  // a native content-desc instead (locate via accessibility-id if needed).

  // Location picker sheet
  locationSearchField: 'location_search_field',
  locationClearSearch: 'location_clear_search',
  locationGpsTile: 'location_gps_tile',
  locationResultTilePrefix: 'location_result_tile',
  locationRecentTilePrefix: 'location_recent_tile',

  // Theme picker sheet
  themeOptionSystem: 'theme_option_system',
  themeOptionLight: 'theme_option_light',
  themeOptionDark: 'theme_option_dark',
};
