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
        _locationName = location.isGps ? null : 'Berlin';
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
                  '48-Hour Forecast',
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

  String _formatLastUpdated(AppLocalizations l10n) {
    if (_weatherData == null) return '';

    final diff = DateTime.now().difference(_weatherData!.fetchedAt);
    if (diff.inMinutes < 1) {
      return l10n.justNow;
    }
    return l10n.minutesAgo(diff.inMinutes);
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
