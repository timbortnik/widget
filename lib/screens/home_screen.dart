import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';
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

  WeatherData? _weatherData;
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
        _loading = false;
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadWeather,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadWeather,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_weatherData == null) {
      return Center(
        child: Text(l10n.errorLoadingData),
      );
    }

    final displayData = _weatherData!.getDisplayRange();
    final currentHour = _weatherData!.getCurrentHour();

    return Column(
      children: [
        // Current weather summary
        if (currentHour != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCurrentStat(
                  icon: Icons.thermostat,
                  value: '${currentHour.temperature.round()}°',
                  label: l10n.temperature,
                ),
                _buildCurrentStat(
                  icon: Icons.water_drop,
                  value: '${currentHour.precipitation.toStringAsFixed(1)} mm',
                  label: l10n.precipitation,
                ),
                _buildCurrentStat(
                  icon: Icons.cloud,
                  value: '${currentHour.cloudCover}%',
                  label: l10n.cloudCover,
                ),
              ],
            ),
          ),

        // Meteogram chart
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: MeteogramChart(data: displayData),
          ),
        ),

        // Last updated
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            l10n.updatedAt(_formatLastUpdated(l10n)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
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
}
