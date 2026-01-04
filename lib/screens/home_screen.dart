import 'dart:async';
import 'dart:typed_data';
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
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _weatherService = WeatherService();
  final _locationService = LocationService();
  final _widgetService = WidgetService();
  final _chartKey = GlobalKey();

  WeatherData? _weatherData;
  String? _locationName;
  bool _loading = true;
  String? _error;
  LocationSource _locationSource = LocationSource.gps;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
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
      });

      // Capture chart after frame is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final imagePath = await _captureChart();
        await _widgetService.updateWidget(
          weatherData: weather,
          locationName: _locationName,
          chartImagePath: imagePath,
        );
      });
    } on LocationException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } on WeatherException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
                onPressed: _loadWeather,
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
    final currentHour = _weatherData!.getCurrentHour();

    return RefreshIndicator(
      onRefresh: _loadWeather,
      color: colors.temperatureLine,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                                    ' · ${_getLocationSourceLabel()}',
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
                            const SizedBox(width: 8),
                            Text(
                              '· ${l10n.updatedAt(_formatLastUpdated(l10n))}',
                              style: TextStyle(
                                color: colors.secondaryText.withAlpha(150),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _loadWeather,
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
                              'Now',
                              style: TextStyle(
                                color: colors.secondaryText,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Stats
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildStatRow(
                            icon: Icons.water_drop_outlined,
                            value: '${currentHour.precipitation.toStringAsFixed(1)} mm',
                            colors: colors,
                          ),
                          const SizedBox(height: 12),
                          _buildStatRow(
                            icon: Icons.cloud_outlined,
                            value: '${currentHour.cloudCover}%',
                            colors: colors,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Forecast label
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  '44-Hour Forecast',
                  style: TextStyle(
                    color: colors.secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Meteogram chart
              Container(
                height: 280,
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
                clipBehavior: Clip.antiAlias,
                child: RepaintBoundary(
                  key: _chartKey,
                  child: MeteogramChart(data: displayData),
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
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.secondaryText),
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
            _loadWeather();
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
          _loadWeather();
        },
        onCitySelected: (city) async {
          Navigator.pop(context);
          await _locationService.addRecentCity(city);
          await _locationService.saveLocation(
            city.latitude,
            city.longitude,
            city: city.name,
          );
          _loadWeather();
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

  String _getLocationSourceLabel() {
    switch (_locationSource) {
      case LocationSource.gps:
        return 'GPS';
      case LocationSource.ip:
        return 'IP';
      case LocationSource.manual:
        return 'Manual';
    }
  }

  Future<String?> _captureChart() async {
    try {
      // Wait a bit for the chart to fully render
      await Future.delayed(const Duration(milliseconds: 500));

      final boundary = _chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      return _widgetService.saveChartImage(byteData.buffer.asUint8List());
    } catch (e) {
      debugPrint('Error capturing chart: $e');
      return null;
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

  const _LocationPickerSheet({
    required this.locationService,
    required this.currentSource,
    required this.currentLocationName,
    required this.colors,
    required this.languageCode,
    required this.onGpsSelected,
    required this.onIpSelected,
    required this.onCitySelected,
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
