import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../l10n/app_localizations.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
import '../services/widget_service.dart';
import '../theme/app_theme.dart';
import '../widgets/meteogram_chart.dart';

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
  final _chartKeyLight = GlobalKey();
  final _chartKeyDark = GlobalKey();

  WeatherData? _weatherData;
  String? _locationName;
  bool _loading = true;
  String? _error;
  LocationSource _locationSource = LocationSource.gps;
  bool _isShowingCachedData = false;
  double _chartAspectRatio = 2.0; // Default 2:1, updated from widget dimensions
  Brightness? _lastRenderedBrightness; // Track theme for re-render on change

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWidgetDimensions();
    _checkAndSyncWidget();
    _loadWeather();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - check if widget was resized
      _checkAndSyncWidget();
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

    final isStale = await _weatherService.isCacheStale();
    if (isStale || wasResized || themeChanged) {
      final cached = await _weatherService.getCachedWeather();
      final cachedCity = await _weatherService.getCachedCityName();
      if (cached != null) {
        // Mark as showing cached data so chart renders with watermark (if stale)
        setState(() {
          _weatherData = cached;
          _locationName = cachedCity;
          _isShowingCachedData = isStale;
        });
        // Update widget (with watermark if stale, or just re-render if resized)
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final paths = await _captureCharts();
          await _widgetService.updateWidget(
            weatherData: cached,
            locationName: cachedCity,
            lightChartPath: paths.light,
            darkChartPath: paths.dark,
          );
        });
      }
    }
  }

  Future<void> _loadWeather({bool userTriggered = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

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
        _isShowingCachedData = false;
      });

      // Cache location info for offline use
      await _weatherService.cacheLocationInfo(location.city, _locationSource.name);

      // Capture chart after frame is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final paths = await _captureCharts();
        await _widgetService.updateWidget(
          weatherData: weather,
          locationName: _locationName,
          lightChartPath: paths.light,
          darkChartPath: paths.dark,
        );
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
          _isShowingCachedData = true;
        });

        // Update widget with cached data (includes OFFLINE watermark)
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final paths = await _captureCharts();
          await _widgetService.updateWidget(
            weatherData: cached,
            locationName: cachedCity,
            lightChartPath: paths.light,
            darkChartPath: paths.dark,
          );
        });

        // Notify user if they triggered the refresh
        if (userTriggered && mounted) {
          _showOfflineSnackbar();
        }
        return;
      }

      // No cache available, show error
      setState(() {
        if (e is LocationException) {
          _error = e.message;
        } else if (e is WeatherException) {
          _error = e.message;
        } else {
          _error = e.toString();
        }
        _loading = false;
      });
    }
  }

  void _showOfflineSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Unable to refresh - showing cached data'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = MeteogramColors.of(context);

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
              'Loading weather...',
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
                'Unable to load weather',
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
    final locale = Localizations.localeOf(context);
    final useImperial = _useImperialUnits(locale);
    final maxPrecip = _getMaxPrecipitation(displayData, nowIndex);
    final maxSunshine = _getMaxSunshine(displayData, nowIndex, _weatherData!.latitude);

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
              // Status banner
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isShowingCachedData ? Icons.history : Icons.check_circle_outline,
                      size: 16,
                      color: colors.secondaryText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.updatedAt(_formatLastUpdated(l10n)),
                      style: TextStyle(
                        color: colors.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.appTitle,
                          style: TextStyle(
                            color: colors.primaryText,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
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
                                    _locationName ?? 'Unknown',
                                    style: TextStyle(
                                      color: colors.secondaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    ' · ${_getLocationSourceLabel(l10n)}',
                                    style: TextStyle(
                                      color: colors.secondaryText.withAlpha(150),
                                      fontSize: 12,
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
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : () => _loadWeather(userTriggered: true),
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: colors.secondaryText,
                    ),
                    tooltip: l10n.refresh,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Current weather card
              if (currentHour != null)
                Container(
                  padding: const EdgeInsets.all(20),
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
                  child: Row(
                    children: [
                      // Temperature
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${currentHour.temperature.round()}°',
                              style: TextStyle(
                                color: colors.primaryText,
                                fontSize: 64,
                                fontWeight: FontWeight.w300,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.now,
                              style: TextStyle(
                                color: colors.secondaryText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Stats
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.secondaryText.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildStatRow(
                              icon: Icons.wb_sunny_outlined,
                              value: l10n.maxSunshine(maxSunshine),
                              colors: colors,
                              iconColor: colors.sunshineIcon,
                            ),
                            const SizedBox(height: 8),
                            _buildStatRow(
                              icon: Icons.water_drop_outlined,
                              value: l10n.maxPrecipitation(_formatPrecipitation(maxPrecip, useImperial)),
                              colors: colors,
                              iconColor: colors.precipitationBar,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Forecast label
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  l10n.forecastHours(kForecastHours),
                  style: TextStyle(
                    color: colors.secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Meteogram chart - aspect ratio matches home widget dimensions
              // Stack contains both themes; both painted for capture, current theme on top
              AspectRatio(
                aspectRatio: _chartAspectRatio,
                child: Builder(
                  builder: (context) {
                    final isLight = Theme.of(context).brightness == Brightness.light;

                    // Use the ACTUAL color scheme for each theme (not current theme's colors)
                    // This ensures widget images look correct in both modes
                    final lightScheme = widget.lightColorScheme ?? Theme.of(context).colorScheme;
                    final darkScheme = widget.darkColorScheme ?? Theme.of(context).colorScheme;

                    // Light theme: onPrimaryContainer for better contrast
                    // Dark theme: primary for brightness
                    final lightTempColor = lightScheme.onPrimaryContainer;
                    final darkTempColor = darkScheme.primary;

                    // Colors for the opposite theme (hidden chart for widget capture)
                    final oppositeColors = isLight
                        ? MeteogramColors.dark.copyWith(
                            temperatureLine: darkTempColor,
                            temperatureGradientStart: darkTempColor.withAlpha(0x60),
                            temperatureGradientEnd: darkTempColor.withAlpha(0x00),
                            timeLabel: darkScheme.tertiary,
                          )
                        : MeteogramColors.light.copyWith(
                            temperatureLine: lightTempColor,
                            temperatureGradientStart: lightTempColor.withAlpha(0x40),
                            temperatureGradientEnd: lightTempColor.withAlpha(0x00),
                            timeLabel: lightScheme.tertiary,
                          );

                    return Stack(
                      children: [
                        // First: chart for NON-current theme (painted for capture, but hidden below)
                        // RepaintBoundary is inside Container so widget capture has transparent background
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isLight
                                  ? MeteogramColors.dark.cardBackground
                                  : MeteogramColors.light.cardBackground,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: RepaintBoundary(
                              key: isLight ? _chartKeyDark : _chartKeyLight,
                              child: MeteogramChart(
                                data: displayData,
                                nowIndex: nowIndex,
                                latitude: _weatherData!.latitude,
                                staleText: _isShowingCachedData && _isCacheStale() ? l10n.offline : null,
                                explicitColors: oppositeColors,
                                explicitLocale: locale.toString(),
                              ),
                            ),
                          ),
                        ),
                        // Second: chart for CURRENT theme (on top, visible to user)
                        // RepaintBoundary is inside Container so widget capture has transparent background
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: colors.cardBackground,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: RepaintBoundary(
                              key: isLight ? _chartKeyLight : _chartKeyDark,
                              child: MeteogramChart(
                                data: displayData,
                                nowIndex: nowIndex,
                                latitude: _weatherData!.latitude,
                                staleText: _isShowingCachedData && _isCacheStale() ? l10n.offline : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
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

    showModalBottomSheet(
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
            _loadWeather(userTriggered: true);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text('GPS permission denied. Enable in device settings.'),
                  action: SnackBarAction(
                    label: 'Settings',
                    onPressed: () => _locationService.openLocationSettings(),
                  ),
                ),
              );
            }
          }
        },
        onIpSelected: () async {
          Navigator.pop(context);
          final location = await _locationService.getIpLocation();
          await _locationService.saveLocation(
            location.latitude,
            location.longitude,
            city: location.city,
            source: LocationSource.ip,
          );
          _loadWeather(userTriggered: true);
        },
        onCitySelected: (city) async {
          Navigator.pop(context);
          await _locationService.addRecentCity(city);
          await _locationService.saveLocation(
            city.latitude,
            city.longitude,
            city: city.name,
          );
          _loadWeather(userTriggered: true);
        },
        onSearchError: () {
          Navigator.pop(context); // Close bottom sheet first
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(
              content: Text('Unable to search - check your connection'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  String _formatLastUpdated(AppLocalizations l10n) {
    if (_weatherData == null) return '';

    final diff = DateTime.now().difference(_weatherData!.fetchedAt);
    if (diff.inMinutes < 1) {
      return l10n.justNow;
    }
    return l10n.minutesAgo(diff.inMinutes);
  }

  /// Check if current weather data is stale (older than 1 hour).
  bool _isCacheStale() {
    if (_weatherData == null) return false;
    return DateTime.now().difference(_weatherData!.fetchedAt) > const Duration(hours: 1);
  }

  /// Get max precipitation from forecast data (from now onwards).
  double _getMaxPrecipitation(List<HourlyData> data, int nowIndex) {
    if (data.isEmpty || nowIndex >= data.length) return 0;
    return data.skip(nowIndex).map((h) => h.precipitation).reduce((a, b) => a > b ? a : b);
  }

  /// Check if locale uses imperial units (US).
  bool _useImperialUnits(Locale locale) {
    return locale.countryCode == 'US';
  }

  /// Format precipitation with localized units.
  String _formatPrecipitation(double mm, bool useImperial) {
    if (useImperial) {
      final inches = mm / 25.4;
      return '${inches.toStringAsFixed(2)} in';
    }
    return '${mm.toStringAsFixed(1)} mm';
  }

  /// Get max sunshine percentage from forecast data (from now onwards).
  /// Uses same calculation as meteogram chart.
  int _getMaxSunshine(List<HourlyData> data, int nowIndex, double latitude) {
    if (data.isEmpty || nowIndex >= data.length) return 0;

    double maxSunshine = 0;
    for (final hour in data.skip(nowIndex)) {
      final elevation = _solarElevation(latitude, hour.time);
      final clearSkyLux = _clearSkyIlluminance(elevation);
      if (clearSkyLux <= 0) continue;

      const maxIlluminance = 130000.0;
      final potential = (clearSkyLux / maxIlluminance).clamp(0.0, 1.0);

      // Cloud attenuation
      final cloudDivisor = math.pow(10, hour.cloudCover / 100.0);
      // Precipitation attenuation
      final precipDivisor = 1 + 0.5 * math.pow(hour.precipitation, 0.6);

      final sunshine = potential / cloudDivisor / precipDivisor;
      if (sunshine > maxSunshine) maxSunshine = sunshine;
    }
    return (maxSunshine * 100).round();
  }

  /// Calculate solar elevation angle in degrees.
  double _solarElevation(double latitude, DateTime time) {
    final dayOfYear = time.difference(DateTime(time.year, 1, 1)).inDays + 1;
    final hour = time.hour + time.minute / 60.0;

    final declination = 23.45 * math.sin(2 * math.pi / 365 * (284 + dayOfYear));
    final hourAngle = 15.0 * (hour - 12);

    final latRad = latitude * math.pi / 180;
    final decRad = declination * math.pi / 180;
    final haRad = hourAngle * math.pi / 180;

    final sinElevation = math.sin(latRad) * math.sin(decRad) +
        math.cos(latRad) * math.cos(decRad) * math.cos(haRad);

    return math.asin(sinElevation.clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  /// Calculate clear-sky illuminance in lux from solar elevation angle.
  double _clearSkyIlluminance(double elevation) {
    if (elevation < -6) return 0;

    final elevRad = elevation * math.pi / 180;
    final u = math.sin(elevRad);

    const x = 753.66156;
    final s = math.asin((x * math.cos(elevRad) / (x + 1)).clamp(-1.0, 1.0));
    final m = x * (math.cos(s) - u) + math.cos(s);

    final factor = math.exp(-0.2 * m) * u +
        0.0289 * math.exp(-0.042 * m) * (1 + (elevation + 90) * u / 57.29577951);

    return 133775 * factor.clamp(0.0, double.infinity);
  }

  IconData _getLocationIcon() {
    switch (_locationSource) {
      case LocationSource.gps:
        return Icons.gps_fixed;
      case LocationSource.ip:
        return Icons.wifi;
      case LocationSource.manual:
        return Icons.edit_location_alt;
    }
  }

  String _getLocationSourceLabel(AppLocalizations l10n) {
    switch (_locationSource) {
      case LocationSource.gps:
        return l10n.locationSourceGps;
      case LocationSource.ip:
        return l10n.locationSourceIp;
      case LocationSource.manual:
        return l10n.locationSourceManual;
    }
  }

  /// Capture both light and dark theme charts, return their paths.
  Future<({String? light, String? dark})> _captureCharts() async {
    try {
      // Wait for both charts to fully render
      await Future.delayed(const Duration(milliseconds: 100));

      // Get actual widget dimensions from native provider
      final widgetDimensions = await _widgetService.getWidgetDimensions();
      final double pixelRatio;
      if (widgetDimensions != null) {
        final boundaryLight = _chartKeyLight.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundaryLight != null && boundaryLight.size.width > 0) {
          pixelRatio = widgetDimensions.widthPx / boundaryLight.size.width;
        } else {
          pixelRatio = MediaQuery.of(context).devicePixelRatio;
        }
        debugPrint('Rendering charts at ${widgetDimensions.widthPx}x${widgetDimensions.heightPx}px');
      } else {
        pixelRatio = MediaQuery.of(context).devicePixelRatio;
        debugPrint('Widget dimensions not available, using device ratio: $pixelRatio');
      }

      String? lightPath;
      String? darkPath;

      // Capture light theme chart
      final boundaryLight = _chartKeyLight.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundaryLight != null) {
        final image = await boundaryLight.toImage(pixelRatio: pixelRatio);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          lightPath = await _widgetService.saveChartImage(byteData.buffer.asUint8List(), isDark: false);
          debugPrint('Light chart captured');
        }
      }

      // Capture dark theme chart
      final boundaryDark = _chartKeyDark.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundaryDark != null) {
        final image = await boundaryDark.toImage(pixelRatio: pixelRatio);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          darkPath = await _widgetService.saveChartImage(byteData.buffer.asUint8List(), isDark: true);
          debugPrint('Dark chart captured');
        }
      }

      _lastRenderedBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return (light: lightPath, dark: darkPath);
    } catch (e) {
      debugPrint('Error capturing charts: $e');
      return (light: null, dark: null);
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
  final VoidCallback onIpSelected;
  final void Function(CitySearchResult) onCitySelected;
  final VoidCallback onSearchError;

  const _LocationPickerSheet({
    required this.locationService,
    required this.currentSource,
    required this.currentLocationName,
    required this.colors,
    required this.languageCode,
    required this.onGpsSelected,
    required this.onIpSelected,
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
                  'Select Location',
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
                    hintText: 'Search city...',
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
                    ..._searchResults.map((city) => _buildCityResultTile(city)),
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
                  // IP option
                  ListTile(
                    leading: Icon(Icons.wifi, color: colors.precipitationBar),
                    title: Text('IP Location', style: TextStyle(color: colors.primaryText)),
                    subtitle: Text('Based on network', style: TextStyle(color: colors.secondaryText, fontSize: 12)),
                    trailing: widget.currentSource == LocationSource.ip
                        ? Icon(Icons.check, color: colors.precipitationBar, size: 20)
                        : null,
                    onTap: widget.onIpSelected,
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
                    ..._recentCities.map((city) => _buildRecentCityTile(city)),
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
