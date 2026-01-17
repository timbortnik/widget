// Application-wide constants.

/// How long weather data remains valid before being considered stale.
const Duration kWeatherStalenessThreshold = Duration(minutes: 15);

/// How often the foreground app checks for stale data and hour boundaries.
const Duration kForegroundRefreshInterval = Duration(minutes: 1);
