import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants.dart';
import '../l10n/app_localizations.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../services/widget_service.dart';
import '../services/svg_chart_generator.dart';
import '../services/units_service.dart';
import '../theme/app_theme.dart';
import '../utils/locale_utils.dart';
import '../widgets/native_svg_chart_view.dart';

/// Main home screen displaying the meteogram.
class HomeScreen extends StatefulWidget {
  final ColorScheme? lightColorScheme;
  final ColorScheme? darkColorScheme;

  const HomeScreen({
    super.key,
    this.lightColorScheme,
    this.darkColorScheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _weatherService = WeatherService();
  final _locationService = LocationService();
  final _widgetService = WidgetService();

  WeatherData? _weatherData;
  String? _locationName;
  bool _loading = true;
  String? _error;
  LocationSource _locationSource = LocationSource.gps;
  double _chartAspectRatio = 2.0; // Default 2:1, updated from widget dimensions
  Brightness? _lastRenderedBrightness; // Track theme for re-render on change
  String _locale = 'en'; // Cached locale for widget generation
  bool _usesFahrenheit = false; // Cached Fahrenheit preference
  bool _isUpdatingWidget = false; // Prevents concurrent widget updates
  bool _isLoadingWeather = false; // Prevents concurrent weather fetches

  // Cached Material You colors for widget SVG generation
  SvgChartColors? _materialYouLightColors;
  SvgChartColors? _materialYouDarkColors;

  // Periodic timer for foreground auto-refresh (every minute)
  Timer? _refreshTimer;
  // Track last hour for detecting hour boundary crossings
  int? _lastRenderedHour;

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
    // Load widget dimensions first (needed for chart aspect ratio)
    await _loadWidgetDimensions();
    // Then initialize weather data
    await _initializeData();
  }

  /// Initialize data on cold start.
  /// Shows cached data immediately while fetching fresh in background.
  Future<void> _initializeData() async {
    // First, immediately show cached data if available (same as widget)
    final cached = await _weatherService.getCachedWeather();
    if (cached != null) {
      final cachedCity = await _weatherService.getCachedCityName();
      final cachedSource = await _weatherService.getCachedLocationSource();
      setState(() {
        _weatherData = cached;
        _locationName = cachedCity;
        if (cachedSource != null) {
          _locationSource = LocationSource.values.firstWhere(
            (s) => s.name == cachedSource,
            orElse: () => LocationSource.gps,
          );
        }
        _loading = false;
        _lastRenderedHour = DateTime.now().hour;
      });
      debugPrint('Showing cached data immediately: ${cached.fetchedAt}');
    }

    // Then try to fetch fresh data in background
    unawaited(
      _loadWeather(showLoadingIndicator: cached == null).catchError((Object error) {
        debugPrint('Background weather fetch failed: $error');
        // Cached data is already displayed, so just log the error
      }),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _weatherService.dispose();
    _locationService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Refresh weather data if stale (>15 min old) or redraw on hour boundary.
  /// Called periodically by _refreshTimer and on first build.
  void _refreshIfStale() {
    if (_weatherData == null || _loading) return;

    final now = DateTime.now();
    final currentHour = now.hour;

    // Check if we've crossed an hour boundary
    if (_lastRenderedHour != null && _lastRenderedHour != currentHour) {
      debugPrint('Hour boundary crossed ($_lastRenderedHour -> $currentHour), redrawing chart...');
      _lastRenderedHour = currentHour;
      setState(() {}); // Trigger rebuild to update "now" indicator position
    }
    _lastRenderedHour ??= currentHour;

    // Check if data is stale
    final age = now.difference(_weatherData!.fetchedAt);
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
  /// Regenerates SVG with current time position.
  Future<void> _updateWidgetOnBackground() async {
    if (_weatherData == null) return;

    try {
      // Generate fresh SVG charts with current time and Material You colors
      await _widgetService.generateAndSaveSvgCharts(
        displayData: _weatherData!.getDisplayRange(),
        nowIndex: _weatherData!.getNowIndex(),
        latitude: _weatherData!.latitude,
        locale: _locale,
        usesFahrenheit: _usesFahrenheit,
        lightColors: _materialYouLightColors,
        darkColors: _materialYouDarkColors,
      );

      // Trigger widget update to load new SVGs
      await _widgetService.updateWidget(
        weatherData: _weatherData!,
        locationName: _locationName,
        locale: LocaleUtils.parseLocaleString(_locale),
      );

      debugPrint('Widget updated on app background');
    } catch (e) {
      debugPrint('Error updating widget on background: $e');
    }
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    // Theme changed while app is running - trigger native widget update to show indicator
    debugPrint('Platform brightness changed - triggering widget update');
    _widgetService.triggerWidgetUpdate();
    // Then re-render after short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _checkAndSyncWidget();
      }
    });
  }

  /// Load widget dimensions and update chart aspect ratio.
  Future<void> _loadWidgetDimensions() async {
    final dimensions = await _widgetService.getWidgetDimensions();
    if (dimensions != null && dimensions.widthPx > 0 && dimensions.heightPx > 0) {
      setState(() {
        _chartAspectRatio = dimensions.widthPx / dimensions.heightPx;
      });
      debugPrint('Chart aspect ratio updated to: $_chartAspectRatio');
    }
  }

  /// Update cached Material You colors for widget SVG generation.
  /// Called from build() when context is available.
  void _updateMaterialYouColors(BuildContext context) {
    // Get dynamic colors from Material You color schemes (if available)
    // Fall back to static colors if no dynamic colors
    final lightMeteogram = widget.lightColorScheme != null
        ? MeteogramColors.fromColorScheme(widget.lightColorScheme!, isDark: false)
        : MeteogramColors.light;
    final darkMeteogram = widget.darkColorScheme != null
        ? MeteogramColors.fromColorScheme(widget.darkColorScheme!, isDark: true)
        : MeteogramColors.dark;

    // Get ARGB values for persistence
    final lightTempColor = lightMeteogram.temperatureLine.toARGB32();
    final lightTimeColor = lightMeteogram.timeLabel.toARGB32();
    final darkTempColor = darkMeteogram.temperatureLine.toARGB32();
    final darkTimeColor = darkMeteogram.timeLabel.toARGB32();

    // Apply dynamic colors to SVG chart colors
    _materialYouLightColors = SvgChartColors.light.withDynamicColors(
      temperatureLine: SvgColor.fromArgb(lightTempColor),
      timeLabel: SvgColor.fromArgb(lightTimeColor),
    );
    _materialYouDarkColors = SvgChartColors.dark.withDynamicColors(
      temperatureLine: SvgColor.fromArgb(darkTempColor),
      timeLabel: SvgColor.fromArgb(darkTimeColor),
    );

    // Persist colors for background service (async, fire-and-forget)
    HomeWidget.saveWidgetData<int>('material_you_light_temp', lightTempColor);
    HomeWidget.saveWidgetData<int>('material_you_light_time', lightTimeColor);
    HomeWidget.saveWidgetData<int>('material_you_dark_temp', darkTempColor);
    HomeWidget.saveWidgetData<int>('material_you_dark_time', darkTimeColor);
  }

  /// Quick check on startup to sync widget state with cache age.
  /// Also handles widget resize and theme changes by re-rendering.
  Future<void> _checkAndSyncWidget() async {
    // Check if widget was resized - if so, force re-render
    final wasResized = await _widgetService.checkAndClearResizeFlag();

    // Reload dimensions if resized
    if (wasResized) {
      await _loadWidgetDimensions();
    }

    // Check if theme changed since last render
    final currentBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isCurrentlyDark = currentBrightness == Brightness.dark;

    // On fresh start, _lastRenderedBrightness is null - read from storage
    bool themeChanged = false;
    if (_lastRenderedBrightness != null) {
      themeChanged = _lastRenderedBrightness != currentBrightness;
    } else {
      // Check stored theme from last render
      final storedDark = await _widgetService.getRenderedTheme();
      if (storedDark != null && storedDark != isCurrentlyDark) {
        themeChanged = true;
        debugPrint('Theme mismatch on startup: stored=${storedDark ? "dark" : "light"}, current=${isCurrentlyDark ? "dark" : "light"}');
      }
    }

    if (themeChanged) {
      debugPrint('Theme changed since last render: $_lastRenderedBrightness -> $currentBrightness');
    }

    // Check if cache has newer data than in-memory (background service may have updated)
    final cached = await _weatherService.getCachedWeather();
    final cacheIsNewer = cached != null &&
        (_weatherData == null || cached.fetchedAt.isAfter(_weatherData!.fetchedAt));

    final isStale = await _weatherService.isCacheStale();
    if (isStale || wasResized || themeChanged || cacheIsNewer) {
      final cachedCity = await _weatherService.getCachedCityName();
      if (cached != null) {
        if (cacheIsNewer) {
          debugPrint('Cache is newer than in-memory data, syncing: ${cached.fetchedAt} > ${_weatherData?.fetchedAt}');
        }
        setState(() {
          _weatherData = cached;
          _locationName = cachedCity;
          _lastRenderedHour = DateTime.now().hour;
        });
        // Update widget after frame is rendered
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _updateWidgetWithData(cached, cached.latitude);
        });
      }
    }
  }

  /// Safely update the home widget with weather data.
  /// Prevents concurrent updates that could cause race conditions.
  Future<void> _updateWidgetWithData(WeatherData weather, double latitude) async {
    // Skip if already updating to prevent race conditions
    if (_isUpdatingWidget) {
      debugPrint('Widget update already in progress, skipping');
      return;
    }

    _isUpdatingWidget = true;
    try {
      // Track brightness for theme change detection
      _lastRenderedBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;

      await _widgetService.updateWidget(
        weatherData: weather,
        locationName: _locationName,
        locale: LocaleUtils.parseLocaleString(_locale),
      );
      // Also generate SVG charts for background widget updates
      await _widgetService.generateAndSaveSvgCharts(
        displayData: weather.getDisplayRange(),
        nowIndex: weather.getNowIndex(),
        latitude: latitude,
        locale: _locale,
        usesFahrenheit: _usesFahrenheit,
        lightColors: _materialYouLightColors,
        darkColors: _materialYouDarkColors,
      );
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
      final weather = await _weatherService.fetchWeather(
        location.latitude,
        location.longitude,
      );

      setState(() {
        _weatherData = weather;
        _locationName = location.city;
        _locationSource = location.source;
        _loading = false;
        _lastRenderedHour = DateTime.now().hour;
      });

      // Cache location info for offline use
      await _weatherService.cacheLocationInfo(location.city, _locationSource.name);

      // Update widget after frame is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _updateWidgetWithData(weather, location.latitude);
      });
    } catch (e) {
      // Try to use cached weather data on any failure
      final cached = await _weatherService.getCachedWeather();
      if (cached != null) {
        final cachedCity = await _weatherService.getCachedCityName();
        final cachedSource = await _weatherService.getCachedLocationSource();
        setState(() {
          _weatherData = cached;
          _locationName = cachedCity;
          if (cachedSource != null) {
            _locationSource = LocationSource.values.firstWhere(
              (s) => s.name == cachedSource,
              orElse: () => LocationSource.gps,
            );
          }
          _loading = false;
          _lastRenderedHour = DateTime.now().hour;
        });

        // Update widget with cached data
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _updateWidgetWithData(cached, cached.latitude);
        });

        // Notify user if they triggered the refresh
        if (userTriggered && mounted) {
          _showOfflineSnackbar();
        }
        return;
      }

      // No cache available, show error
      setState(() {
        if (e is WeatherException) {
          _error = e.message;
        } else {
          _error = e.toString();
        }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = MeteogramColors.of(context);

    // Update cached Material You colors for widget SVG generation
    _updateMaterialYouColors(context);

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
            ],
          ),
        ),
      );
    }

    if (_weatherData == null) {
      return Center(
        child: Text(
          l10n.errorLoadingData,
          style: TextStyle(color: colors.secondaryText),
        ),
      );
    }

    final displayData = _weatherData!.getDisplayRange();
    final nowIndex = _weatherData!.getNowIndex();
    final currentHour = _weatherData!.getCurrentHour();

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
              // Location row
              GestureDetector(
                onTap: _showLocationPicker,
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
              const SizedBox(height: 16),

              // Unified weather card: temperature + legend + chart
              if (currentHour != null)
                Container(
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
                                  UnitsService.formatTemperature(currentHour.temperature, PlatformDispatcher.instance.locale),
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
                      // Meteogram chart - Native PlatformView for exact widget match
              AspectRatio(
                aspectRatio: _chartAspectRatio,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Check staleness on first build (cold start after long time)
                    _refreshIfStale();

                    final isLight = Theme.of(context).brightness == Brightness.light;
                    final mediaQuery = MediaQuery.of(context);
                    final dpr = mediaQuery.devicePixelRatio;
                    // Get locale for time formatting and temperature units
                    // Use platform locale (not Flutter's resolved locale) to get country code for unit preferences
                    final platformLocale = PlatformDispatcher.instance.locale;
                    final locale = platformLocale.toString();
                    final usesFahrenheit = UnitsService.usesFahrenheit(platformLocale);
                    _locale = locale;
                    _usesFahrenheit = usesFahrenheit;
                    // Save for background service
                    HomeWidget.saveWidgetData<String>('locale', locale);
                    HomeWidget.saveWidgetData<bool>('usesFahrenheit', usesFahrenheit);

                    // Generate SVG at device pixel dimensions - same as widget approach
                    final deviceWidth = constraints.maxWidth * dpr;
                    final deviceHeight = constraints.maxHeight * dpr;

                    // Apply Material You dynamic colors
                    final meteogramColors = MeteogramColors.of(context);
                    final baseColors = isLight ? SvgChartColors.light : SvgChartColors.dark;
                    final colors = baseColors.withDynamicColors(
                      temperatureLine: SvgColor.fromArgb(meteogramColors.temperatureLine.toARGB32()),
                      timeLabel: SvgColor.fromArgb(meteogramColors.timeLabel.toARGB32()),
                    );

                    final generator = SvgChartGenerator();
                    final svgString = generator.generate(
                      data: displayData,
                      nowIndex: nowIndex,
                      latitude: _weatherData!.latitude,
                      colors: colors,
                      width: deviceWidth,
                      height: deviceHeight,
                      locale: locale,
                      usesFahrenheit: usesFahrenheit,
                    );

                    return NativeSvgChartView(
                      svgString: svgString,
                      width: deviceWidth,
                      height: deviceHeight,
                    );
                  },
                ),
              ),
                    ],
                  ),
                ),

              // Attribution (CC BY 4.0 requirement)
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://open-meteo.com')),
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
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://github.com/timbortnik/widget')),
                child: Text(
                  l10n.sourceCode,
                  style: TextStyle(
                    color: colors.secondaryText,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final colors = MeteogramColors.of(context);
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
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Header and search (fixed)
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
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: colors.primaryText),
                  decoration: InputDecoration(
                    hintText: l10n.searchCityHint,
                    hintStyle: TextStyle(color: colors.secondaryText),
                    prefixIcon: Icon(Icons.search, color: colors.secondaryText),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: colors.secondaryText),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
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
              ],
            ),
          ),
          // Content (scrollable)
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
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
                    ..._searchResults.map(_buildCityResultTile),
                ] else ...[
                  // GPS option
                  ListTile(
                    leading: Icon(Icons.gps_fixed, color: colors.temperatureLine),
                    title: Text('GPS', style: TextStyle(color: colors.primaryText)),
                    subtitle: Text('Device location', style: TextStyle(color: colors.secondaryText, fontSize: 12)),
                    trailing: widget.currentSource == LocationSource.gps
                        ? Icon(Icons.check, color: colors.temperatureLine, size: 20)
                        : null,
                    onTap: widget.onGpsSelected,
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
                    ..._recentCities.map(_buildRecentCityTile),
                  ],
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityResultTile(CitySearchResult city) {
    return ListTile(
      leading: Icon(Icons.location_city, color: widget.colors.secondaryText),
      title: Text(city.name, style: TextStyle(color: widget.colors.primaryText)),
      subtitle: Text(
        city.displayName != city.name ? city.displayName : city.country,
        style: TextStyle(color: widget.colors.secondaryText, fontSize: 12),
      ),
      onTap: () => widget.onCitySelected(city),
    );
  }

  Widget _buildRecentCityTile(CitySearchResult city) {
    final isSelected = widget.currentSource == LocationSource.manual &&
        widget.currentLocationName == city.name;
    return ListTile(
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
    );
  }
}
