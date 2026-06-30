import 'dart:async';
import 'dart:typed_data' show Uint8List;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import '../a11y_ids.dart';
import '../constants.dart';
import '../l10n/app_localizations.dart';
import '../services/location_service.dart';
import '../services/widget_service.dart';
import '../services/native_svg_service.dart';
import '../services/units_service.dart';
import '../services/material_you_service.dart';
import '../services/widget_store.dart';
import '../theme/app_theme.dart';
import '../generated/version.dart';

/// Wraps [child] so black-box UI tests (Appium + UiAutomator2) can locate it by
/// [id]: a Flutter `Semantics(identifier:)` surfaces to Android as the node's
/// `resource-id`. `MergeSemantics` collapses the subtree into a SINGLE node so
/// the resource-id, label (`content-desc`) and tap action all land together — a
/// bare `Semantics` wrapper would otherwise put the id on a non-clickable
/// parent node. Identifier values live in `lib/a11y_ids.dart`.
Widget _identified(
  String id,
  Widget child, {
  bool? button,
  bool? link,
  bool? image,
  bool? selected,
  String? label,
}) {
  return MergeSemantics(
    child: Semantics(
      identifier: id,
      button: button,
      link: link,
      image: image,
      selected: selected,
      label: label,
      child: child,
    ),
  );
}

/// Main home screen displaying the meteogram.
class HomeScreen extends StatefulWidget {
  final MaterialYouColors? materialYouColors;

  /// Currently active in-app theme mode (used to show the chooser selection).
  final ThemeMode themeMode;

  /// Called when the user picks a theme mode from the chooser.
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  const HomeScreen({
    super.key,
    this.materialYouColors,
    this.themeMode = ThemeMode.system,
    this.onThemeModeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _locationService = LocationService();
  final _widgetService = WidgetService();

  // Weather data (simplified - Kotlin owns the full data, Dart just displays)
  DateTime? _weatherFetchedAt;
  double? _currentTemperatureCelsius;
  String? _locationName;
  bool _loading = true;
  String? _error;
  LocationSource _locationSource = LocationSource.gps;
  static const double _chartAspectRatio = 2.0; // Fixed 2:1 for in-app display
  Brightness? _lastRenderedBrightness; // Track theme for re-render on change
  bool _isUpdatingWidget = false; // Prevents concurrent widget updates
  bool _isLoadingWeather = false; // Prevents concurrent weather fetches

  // Cached SVG strings for in-app chart display, keyed by chart mode.
  final Map<String, _ChartCacheEntry> _chartCache = {
    NativeSvgService.chartModeHourly: _ChartCacheEntry(),
    NativeSvgService.chartModeWeekly: _ChartCacheEntry(),
  };

  void _invalidateChartCaches() {
    for (final entry in _chartCache.values) {
      entry.png = null;
    }
  }

  // Periodic timer for foreground auto-refresh (every minute)
  Timer? _refreshTimer;
  // Track last display hour for detecting half-hour boundary crossings
  // The "now" indicator snaps to nearest hour at :30, so we track that
  int? _lastDisplayHour;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
    // Start periodic refresh timer (checks staleness and hour boundaries)
    _refreshTimer = Timer.periodic(kForegroundRefreshInterval, (_) {
      _refreshIfStale();
    });
  }

  /// Combined initialization: load dimensions first, then data.
  /// Ensures chart renders with correct aspect ratio from the start.
  Future<void> _initialize() async {
    // Save locale/units early for background service
    await _saveLocaleAndUnits();
    // Check for widget resize and load dimensions
    // This handles both fresh launch and resume scenarios
    await _checkAndSyncWidget();
    // Then initialize weather data
    await _initializeData();
  }

  /// Save locale and units preferences to the shared widget store for background service.
  /// Called early in initialization so background can use correct settings.
  Future<void> _saveLocaleAndUnits() async {
    final platformLocale = PlatformDispatcher.instance.locale;
    final locale = platformLocale.toString();
    final usesFahrenheit = UnitsService.usesFahrenheit(platformLocale);

    await WidgetStore.saveWidgetData<String>('locale', locale);
    await WidgetStore.saveWidgetData<bool>('usesFahrenheit', usesFahrenheit);

    debugPrint('Saved locale/units at startup: $locale, usesFahrenheit=$usesFahrenheit');
  }

  /// Initialize data on cold start.
  /// Shows cached data immediately while fetching fresh in background.
  Future<void> _initializeData() async {
    // First, immediately show cached data if available (same as widget)
    final hasCached = await NativeSvgService.hasWeatherData();
    if (hasCached) {
      final cachedTemp = await NativeSvgService.getCurrentTemperatureCelsius();
      final cachedTime = await NativeSvgService.getLastWeatherUpdate();
      final cachedCity = await NativeSvgService.getCachedCityName();
      final cachedSource = await NativeSvgService.getCachedLocationSource();
      setState(() {
        _currentTemperatureCelsius = cachedTemp;
        _weatherFetchedAt = cachedTime;
        _locationName = cachedCity;
        if (cachedSource != null) {
          _locationSource = LocationSource.values.firstWhere(
            (s) => s.name == cachedSource,
            orElse: () => LocationSource.gps,
          );
        }
        _loading = false;
        _lastDisplayHour = DateTime.now().minute >= 30 ? (DateTime.now().hour + 1) % 24 : DateTime.now().hour;
        _invalidateChartCaches();
      });
      debugPrint('Showing cached data immediately: $_weatherFetchedAt');
    }

    // Then try to fetch fresh data in background
    unawaited(
      _loadWeather(showLoadingIndicator: !hasCached).catchError((Object error) {
        debugPrint('Background weather fetch failed: $error');
        // Cached data is already displayed, so just log the error
      }),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Refresh weather data if stale (>15 min old) or redraw on half-hour boundary.
  /// Called periodically by _refreshTimer and on first build.
  void _refreshIfStale() {
    if (_weatherFetchedAt == null || _loading) return;

    final now = DateTime.now();
    // The "now" indicator snaps to nearest hour at :30
    // So displayHour is the rounded hour (same logic as getNowIndex)
    final displayHour = now.minute >= 30 ? (now.hour + 1) % 24 : now.hour;

    // Check if we've crossed a half-hour boundary (display hour changed)
    if (_lastDisplayHour != null && _lastDisplayHour != displayHour) {
      debugPrint('Half-hour boundary crossed ($_lastDisplayHour -> $displayHour), redrawing chart...');
      _lastDisplayHour = displayHour;
      _invalidateChartCaches();
      setState(() {}); // Trigger rebuild to update "now" indicator position
    }
    _lastDisplayHour ??= displayHour;

    // Check if data is stale
    final age = now.difference(_weatherFetchedAt!);
    if (age >= kWeatherStalenessThreshold) {
      debugPrint('Data is ${age.inMinutes} min old, refreshing...');
      _loadWeather(showLoadingIndicator: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - check if widget was resized
      _checkAndSyncWidget();
    } else if (state == AppLifecycleState.paused) {
      // App going to background - update widget with fresh chart
      _updateWidgetOnBackground();
    }
  }

  /// Update widget when app goes to background.
  /// Triggers native widget update which generates fresh SVG.
  Future<void> _updateWidgetOnBackground() async {
    try {
      await _widgetService.triggerWidgetUpdate();
      debugPrint('Widget updated on app background');
    } catch (e) {
      debugPrint('Error updating widget on background: $e');
    }
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    // Theme changed while app is running - invalidate cached SVG and trigger widget update
    debugPrint('Platform brightness changed - triggering widget update');
    _invalidateChartCaches();
    _widgetService.triggerWidgetUpdate();
    // Then re-render after short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _checkAndSyncWidget();
      }
    });
  }

  /// Quick check on startup to sync widget state with cache age.
  /// Also handles widget resize and theme changes by re-rendering.
  Future<void> _checkAndSyncWidget() async {
    // Check if widget was resized - if so, force re-render
    final wasResized = await _widgetService.checkAndClearResizeFlag();

    // Check if theme changed since last render
    final currentBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final themeChanged = _lastRenderedBrightness != null && _lastRenderedBrightness != currentBrightness;
    if (themeChanged) {
      debugPrint('Theme changed since last render: $_lastRenderedBrightness -> $currentBrightness');
    }

    // Check if cache has newer data than in-memory (background service may have updated)
    final cachedTime = await NativeSvgService.getLastWeatherUpdate();
    final cacheIsNewer = cachedTime != null &&
        (_weatherFetchedAt == null || cachedTime.isAfter(_weatherFetchedAt!));

    final isStale = await NativeSvgService.isCacheStale();
    if (isStale || wasResized || themeChanged || cacheIsNewer) {
      final cachedTemp = await NativeSvgService.getCurrentTemperatureCelsius();
      final cachedCity = await NativeSvgService.getCachedCityName();
      if (cachedTime != null) {
        if (cacheIsNewer) {
          debugPrint('Cache is newer than in-memory data, syncing: $cachedTime > $_weatherFetchedAt');
        }
        setState(() {
          _currentTemperatureCelsius = cachedTemp;
          _weatherFetchedAt = cachedTime;
          _locationName = cachedCity;
          _lastDisplayHour = DateTime.now().minute >= 30 ? (DateTime.now().hour + 1) % 24 : DateTime.now().hour;
          _invalidateChartCaches();
        });
        // Update widget after frame is rendered
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _updateWidget();
        });
      }
    }
  }

  /// Safely update the home widget.
  /// Prevents concurrent updates that could cause race conditions.
  Future<void> _updateWidget() async {
    // Skip if already updating to prevent race conditions
    if (_isUpdatingWidget) {
      debugPrint('Widget update already in progress, skipping');
      return;
    }

    _isUpdatingWidget = true;
    try {
      // Track brightness for theme change detection
      _lastRenderedBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;

      // Trigger native widget update - SVG is generated natively from cached weather
      await _widgetService.triggerWidgetUpdate();
    } finally {
      _isUpdatingWidget = false;
    }
  }

  Future<void> _loadWeather({
    bool userTriggered = false,
    bool showLoadingIndicator = true,
  }) async {
    // Prevent concurrent weather fetches (unless user explicitly triggered)
    if (_isLoadingWeather && !userTriggered) {
      debugPrint('Weather fetch already in progress, skipping');
      return;
    }

    _isLoadingWeather = true;

    if (showLoadingIndicator) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final location = await _locationService.getLocation();

      // Fetch weather via native Kotlin HTTP client
      final success = await NativeSvgService.fetchWeather(
        latitude: location.latitude,
        longitude: location.longitude,
      );

      if (!success) {
        throw Exception(
          NativeSvgService.lastFetchError ?? 'Failed to fetch weather data',
        );
      }

      // Read the cached values (Kotlin saves current temp and timestamp)
      final temp = await NativeSvgService.getCurrentTemperatureCelsius();
      final fetchedAt = await NativeSvgService.getLastWeatherUpdate();

      setState(() {
        _currentTemperatureCelsius = temp;
        _weatherFetchedAt = fetchedAt;
        _locationName = location.city;
        _locationSource = location.source;
        _loading = false;
        _lastDisplayHour = DateTime.now().minute >= 30 ? (DateTime.now().hour + 1) % 24 : DateTime.now().hour;
        _invalidateChartCaches();
      });

      // Cache location info for offline use
      await NativeSvgService.cacheLocationInfo(location.city, _locationSource.name);

      // Update widget after frame is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _updateWidget();
      });
    } catch (e) {
      // Try to use cached weather data on any failure
      final hasCached = await NativeSvgService.hasWeatherData();
      if (hasCached) {
        final cachedTemp = await NativeSvgService.getCurrentTemperatureCelsius();
        final cachedTime = await NativeSvgService.getLastWeatherUpdate();
        final cachedCity = await NativeSvgService.getCachedCityName();
        final cachedSource = await NativeSvgService.getCachedLocationSource();
        setState(() {
          _currentTemperatureCelsius = cachedTemp;
          _weatherFetchedAt = cachedTime;
          _locationName = cachedCity;
          if (cachedSource != null) {
            _locationSource = LocationSource.values.firstWhere(
              (s) => s.name == cachedSource,
              orElse: () => LocationSource.gps,
            );
          }
          _loading = false;
          _lastDisplayHour = DateTime.now().minute >= 30 ? (DateTime.now().hour + 1) % 24 : DateTime.now().hour;
          _invalidateChartCaches();
        });

        // Update widget with cached data
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _updateWidget();
        });

        // Notify user if they triggered the refresh
        if (userTriggered && mounted) {
          _showOfflineSnackbar();
        }
        return;
      }

      // No cache available, show error
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      _isLoadingWeather = false;
    }
  }

  void _showOfflineSnackbar() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.offlineRefreshError),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Get the native Material You colors for the current theme brightness.
  MaterialYouThemeColors? _getNativeColorsForTheme(BuildContext context) {
    if (widget.materialYouColors == null) return null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? widget.materialYouColors!.dark : widget.materialYouColors!.light;
  }

  /// Generate the chart asynchronously using the native Kotlin generator, then
  /// rasterize it to PNG natively for display via a plain Flutter [Image]
  /// (no PlatformView — see [NativeSvgService.renderSvgToPng]).
  /// Updates the cache entry for [mode] and triggers rebuild when complete.
  /// For hourly mode, also syncs current_temperature_celsius with nowIndex.
  Future<void> _generateSvgAsync({
    required String mode,
    required int width,
    required int height,
    required bool isLight,
    required bool usesFahrenheit,
  }) async {
    try {
      final svgString = await NativeSvgService.generateSvg(
        mode: mode,
        width: width,
        height: height,
        isLight: isLight,
        usesFahrenheit: usesFahrenheit,
      );
      if (svgString == null || !mounted) return;

      final png = await NativeSvgService.renderSvgToPng(
        svg: svgString,
        width: width,
        height: height,
      );
      if (png == null || !mounted) return;

      final updatedTemp = mode == NativeSvgService.chartModeHourly
          ? await NativeSvgService.getCurrentTemperatureCelsius()
          : null;

      setState(() {
        final cache = _chartCache[mode]!;
        cache.png = png;
        cache.width = width;
        cache.height = height;
        cache.isLight = isLight;
        if (updatedTemp != null) {
          _currentTemperatureCelsius = updatedTemp;
        }
      });
    } catch (e) {
      debugPrint('Error generating chart ($mode): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = MeteogramColors.of(context, nativeColors: _getNativeColorsForTheme(context));

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: _buildBody(l10n, colors),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, MeteogramColors colors) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colors.temperatureLine,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.loadingWeather,
              style: TextStyle(
                color: colors.secondaryText,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 56,
                  color: colors.secondaryText,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.unableToLoadWeather,
                style: TextStyle(
                  color: colors.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.secondaryText,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              _identified(
                A11yIds.homeRetryButton,
                FilledButton.icon(
                  onPressed: () => _loadWeather(userTriggered: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retry),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                button: true,
              ),
            ],
          ),
        ),
      );
    }

    if (_currentTemperatureCelsius == null) {
      return Center(
        child: Text(
          l10n.errorLoadingData,
          style: TextStyle(color: colors.secondaryText),
        ),
      );
    }

    final currentTemp = _currentTemperatureCelsius!;

    return RefreshIndicator(
      onRefresh: () => _loadWeather(userTriggered: true),
      color: colors.temperatureLine,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: location selector + theme switcher
              Row(
                children: [
                  _identified(
                    A11yIds.homeLocationSelector,
                    GestureDetector(
                      onTap: _showLocationPicker,
                      behavior: HitTestBehavior.opaque,
                      // 48dp minimum tap target (ADA); content stays visually
                      // small, vertically centered within the row.
                      child: SizedBox(
                        height: 48,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getLocationIcon(),
                              size: 14,
                              color: colors.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _locationName ?? l10n.unknownLocation,
                              style: TextStyle(
                                color: colors.secondaryText,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              ' · ${_getLocationSourceLabel(l10n)}',
                              style: TextStyle(
                                color: colors.secondaryText,
                                fontSize: 13,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 16,
                              color: colors.secondaryText,
                            ),
                          ],
                        ),
                      ),
                    ),
                    button: true,
                  ),
                  const Spacer(),
                  _identified(
                    A11yIds.homeThemeButton,
                    IconButton(
                      onPressed: _showThemePicker,
                      icon: Icon(
                        Icons.brightness_medium_outlined,
                        size: 20,
                        color: colors.secondaryText,
                      ),
                      tooltip: l10n.theme,
                      // 48dp minimum hit area for accessibility (icon stays
                      // visually 20px, centered). Do not re-add
                      // VisualDensity.compact — it shrinks the target below 48.
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Unified weather card: temperature + legend + chart
              Center(
              child: Container(
                // Landscape now hosts two charts side by side; give the card
                // more horizontal room than the single-chart layout needed.
                constraints: MediaQuery.of(context).orientation == Orientation.landscape
                    ? BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.95)
                    : null,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Temperature row with legend
                      Row(
                        children: [
                          // Temperature
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  UnitsService.formatTemperature(currentTemp, PlatformDispatcher.instance.locale),
                                  style: TextStyle(
                                    color: colors.temperatureLine,
                                    fontSize: 64,
                                    fontWeight: FontWeight.w300,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Chart legend
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildStatRow(
                                icon: Icons.wb_sunny_outlined,
                                value: l10n.daylight,
                                colors: colors,
                                iconColor: colors.daylightIcon,
                              ),
                              const SizedBox(height: 8),
                              _buildStatRow(
                                icon: Icons.water_drop_outlined,
                                value: l10n.precipitation,
                                colors: colors,
                                iconColor: colors.precipitationBar,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Meteograph charts - 48h on top/left, 7-day stacked/next to it.
                      // Portrait = Column, landscape = Row (each chart gets half width).
                      // Use device orientation (not layout constraints), since the enclosing
                      // card is width-constrained and would otherwise always look portrait.
                      Builder(
                        builder: (context) {
                          final orientation = MediaQuery.of(context).orientation;
                          if (orientation == Orientation.landscape) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildChart(mode: NativeSvgService.chartModeHourly)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildChart(mode: NativeSvgService.chartModeWeekly)),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              _buildChart(mode: NativeSvgService.chartModeHourly),
                              const SizedBox(height: 12),
                              _buildChart(mode: NativeSvgService.chartModeWeekly),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Attribution (CC BY 4.0 requirement)
              const SizedBox(height: 16),
              _identified(
                A11yIds.homeOpenMeteoLink,
                GestureDetector(
                  onTap: () => NativeSvgService.openUrl('https://open-meteo.com'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.weatherDataBy('Open-Meteo.com'),
                        style: TextStyle(
                          color: colors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        l10n.daylightDerived,
                        style: TextStyle(
                          color: colors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                link: true,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _identified(
                    A11yIds.homeGithubLink,
                    GestureDetector(
                      onTap: () => NativeSvgService.openUrl('https://github.com/timbortnik/widget'),
                      child: Text(
                        l10n.sourceCode,
                        style: TextStyle(
                          color: colors.secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    link: true,
                  ),
                  Text(
                    ' ${AppVersion.version}',
                    style: TextStyle(
                      color: colors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart({required String mode}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check staleness on first build (cold start after long time)
        _refreshIfStale();

        final chartWidth = constraints.maxWidth;
        final chartHeight = chartWidth / _chartAspectRatio;

        final isLight = Theme.of(context).brightness == Brightness.light;
        final mediaQuery = MediaQuery.of(context);
        final dpr = mediaQuery.devicePixelRatio;
        final platformLocale = PlatformDispatcher.instance.locale;
        final usesFahrenheit = UnitsService.usesFahrenheit(platformLocale);

        final deviceWidthPx = (chartWidth * dpr).round();
        final deviceHeightPx = (chartHeight * dpr).round();

        final cache = _chartCache[mode]!;
        final needsRegeneration = cache.png == null ||
            cache.width != deviceWidthPx ||
            cache.height != deviceHeightPx ||
            cache.isLight != isLight;

        if (needsRegeneration) {
          _generateSvgAsync(
            mode: mode,
            width: deviceWidthPx,
            height: deviceHeightPx,
            isLight: isLight,
            usesFahrenheit: usesFahrenheit,
          );
        }

        final l10n = AppLocalizations.of(context)!;
        final isHourly = mode == NativeSvgService.chartModeHourly;
        final chartLabel =
            isHourly ? l10n.hourlyChartLabel : l10n.weeklyChartLabel;

        if (cache.png != null) {
          // Plain Flutter Image over natively-rasterized PNG bytes — NOT a
          // PlatformView, so it stays out of Impeller's external-texture path
          // (which crashes on some Vulkan devices). A real Semantics node now
          // reaches the widget, carrying both a resource-id and a content-desc
          // label for TalkBack and Appium. `gaplessPlayback` keeps the current
          // frame on screen while a new one (theme/resize) decodes.
          return SizedBox(
            width: chartWidth,
            height: chartHeight,
            child: Semantics(
              identifier: isHourly
                  ? A11yIds.homeHourlyChart
                  : A11yIds.homeWeeklyChart,
              label: chartLabel,
              image: true,
              child: Image.memory(
                cache.png!,
                width: chartWidth,
                height: chartHeight,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
          );
        }
        return SizedBox(width: chartWidth, height: chartHeight);
      },
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String value,
    required MeteogramColors colors,
    Color? iconColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor ?? colors.secondaryText),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: colors.primaryText,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showLocationPicker() {
    final colors = MeteogramColors.of(context, nativeColors: _getNativeColorsForTheme(context));
    final locale = Localizations.localeOf(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => _LocationPickerSheet(
        locationService: _locationService,
        currentSource: _locationSource,
        currentLocationName: _locationName,
        colors: colors,
        languageCode: locale.languageCode,
        onGpsSelected: () async {
          Navigator.pop(context);
          final hasPermission = await _locationService.requestGpsPermission();
          if (hasPermission) {
            await _locationService.useGpsLocation();
            await _loadWeather(userTriggered: true);
          } else {
            if (mounted) {
              final l10n = AppLocalizations.of(this.context)!;
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(l10n.gpsPermissionDenied),
                  action: SnackBarAction(
                    label: l10n.settings,
                    onPressed: _locationService.openLocationSettings,
                  ),
                ),
              );
            }
          }
        },
        onCitySelected: (city) async {
          Navigator.pop(context);
          await _locationService.addRecentCity(city);
          await _locationService.saveLocation(
            city.latitude,
            city.longitude,
            city: city.name,
          );
          await _loadWeather(userTriggered: true);
        },
        onSearchError: () {
          Navigator.pop(context); // Close bottom sheet first
          final l10n = AppLocalizations.of(this.context)!;
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(l10n.searchConnectionError),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  /// Bottom sheet to choose the in-app theme: System default / Light / Dark.
  void _showThemePicker() {
    final colors = MeteogramColors.of(context, nativeColors: _getNativeColorsForTheme(context));
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        Widget tile(ThemeMode mode, IconData icon, String label, String id) {
          return _identified(
            id,
            ListTile(
              leading: Icon(icon, color: colors.temperatureLine),
              title: Text(label, style: TextStyle(color: colors.primaryText)),
              trailing: widget.themeMode == mode
                  ? Icon(Icons.check, color: colors.temperatureLine, size: 20)
                  : null,
              onTap: () {
                Navigator.pop(sheetContext);
                widget.onThemeModeChanged?.call(mode);
              },
            ),
            // Exposes which option is active (UiAutomator2 `selected` attribute)
            // — announced by screen readers and asserted by the E2E theme-switch
            // test.
            selected: widget.themeMode == mode,
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.theme,
                    style: TextStyle(
                      color: colors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              tile(ThemeMode.system, Icons.brightness_auto_outlined,
                  l10n.themeSystem, A11yIds.themeOptionSystem),
              tile(ThemeMode.light, Icons.light_mode_outlined, l10n.themeLight,
                  A11yIds.themeOptionLight),
              tile(ThemeMode.dark, Icons.dark_mode_outlined, l10n.themeDark,
                  A11yIds.themeOptionDark),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  IconData _getLocationIcon() {
    switch (_locationSource) {
      case LocationSource.gps:
        return Icons.gps_fixed;
      case LocationSource.manual:
        return Icons.edit_location_alt;
    }
  }

  String _getLocationSourceLabel(AppLocalizations l10n) {
    switch (_locationSource) {
      case LocationSource.gps:
        return l10n.locationSourceGps;
      case LocationSource.manual:
        return l10n.locationSourceManual;
    }
  }

}

/// Location picker bottom sheet with search functionality.
class _LocationPickerSheet extends StatefulWidget {
  final LocationService locationService;
  final LocationSource currentSource;
  final String? currentLocationName;
  final MeteogramColors colors;
  final String languageCode;
  final VoidCallback onGpsSelected;
  final void Function(CitySearchResult) onCitySelected;
  final VoidCallback onSearchError;

  const _LocationPickerSheet({
    required this.locationService,
    required this.currentSource,
    required this.currentLocationName,
    required this.colors,
    required this.languageCode,
    required this.onGpsSelected,
    required this.onCitySelected,
    required this.onSearchError,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchController = TextEditingController();
  List<CitySearchResult> _searchResults = [];
  List<CitySearchResult> _recentCities = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadRecentCities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentCities() async {
    final cities = await widget.locationService.getRecentCities();
    if (mounted) {
      setState(() => _recentCities = cities);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await widget.locationService.searchCities(
          query,
          language: widget.languageCode,
        );
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
          widget.onSearchError();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final l10n = AppLocalizations.of(context)!;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          // Header and search
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.selectLocation,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                // Search field
                // Bare Semantics (not MergeSemantics) so the suffix clear button
                // keeps its own node and identifier instead of being merged in.
                Semantics(
                  identifier: A11yIds.locationSearchField,
                  textField: true,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: TextStyle(color: colors.primaryText),
                    decoration: InputDecoration(
                      hintText: l10n.searchCityHint,
                      hintStyle: TextStyle(color: colors.secondaryText),
                      prefixIcon: Icon(Icons.search, color: colors.secondaryText),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? _identified(
                              A11yIds.locationClearSearch,
                              IconButton(
                                icon: Icon(Icons.clear, color: colors.secondaryText),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              ),
                              button: true,
                              label: l10n.clearSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: colors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Show search results if searching
          if (_searchController.text.trim().length >= 2) ...[
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.temperatureLine,
                    ),
                  ),
                ),
              )
            else if (_searchResults.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No cities found',
                    style: TextStyle(color: colors.secondaryText),
                  ),
                ),
              )
            else
              ..._searchResults.indexed.map((e) => _buildCityResultTile(e.$2, e.$1)),
          ] else ...[
            // GPS option
            _identified(
              A11yIds.locationGpsTile,
              ListTile(
                leading: Icon(Icons.gps_fixed, color: colors.temperatureLine),
                title: Text('GPS', style: TextStyle(color: colors.primaryText)),
                subtitle: Text('Device location', style: TextStyle(color: colors.secondaryText, fontSize: 12)),
                trailing: widget.currentSource == LocationSource.gps
                    ? Icon(Icons.check, color: colors.temperatureLine, size: 20)
                    : null,
                onTap: widget.onGpsSelected,
              ),
            ),
            // Recent cities
            if (_recentCities.isNotEmpty) ...[
              Divider(color: colors.gridLine),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Recent',
                  style: TextStyle(color: colors.secondaryText, fontSize: 12),
                ),
              ),
              ..._recentCities.indexed.map((e) => _buildRecentCityTile(e.$2, e.$1)),
            ],
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCityResultTile(CitySearchResult city, int index) {
    return _identified(
      '${A11yIds.locationResultTilePrefix}_$index',
      ListTile(
        leading: Icon(Icons.location_city, color: widget.colors.secondaryText),
        title: Text(city.name, style: TextStyle(color: widget.colors.primaryText)),
        subtitle: Text(
          city.displayName != city.name ? city.displayName : city.country,
          style: TextStyle(color: widget.colors.secondaryText, fontSize: 12),
        ),
        onTap: () => widget.onCitySelected(city),
      ),
    );
  }

  Widget _buildRecentCityTile(CitySearchResult city, int index) {
    final isSelected = widget.currentSource == LocationSource.manual &&
        widget.currentLocationName == city.name;
    return _identified(
      '${A11yIds.locationRecentTilePrefix}_$index',
      ListTile(
        leading: Icon(Icons.history, color: widget.colors.secondaryText),
        title: Text(city.name, style: TextStyle(color: widget.colors.primaryText)),
        subtitle: Text(
          city.country,
          style: TextStyle(color: widget.colors.secondaryText, fontSize: 12),
        ),
        trailing: isSelected
            ? Icon(Icons.check, color: widget.colors.nowIndicator, size: 20)
            : null,
        onTap: () => widget.onCitySelected(city),
      ),
    );
  }
}

/// Per-mode cache of the last-rendered SVG plus the params used to generate it.
class _ChartCacheEntry {
  /// Rasterized PNG bytes for the chart, displayed via [Image.memory].
  /// The same instance is reused across rebuilds so [MemoryImage] equality
  /// hits Flutter's image cache and the bitmap is not re-decoded.
  Uint8List? png;
  int? width;
  int? height;
  bool? isLight;
}
