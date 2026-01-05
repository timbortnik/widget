import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../models/weather_data.dart';
import '../theme/app_theme.dart';

/// Calculate solar elevation angle in degrees.
/// Returns negative values when sun is below horizon.
///
/// Formula based on standard astronomical calculations:
/// - Solar declination: δ = 23.45° × sin(360/365 × (284 + dayOfYear))
/// - Hour angle: h = 15° × (hour - 12)
/// - Elevation: sin(α) = sin(lat)×sin(δ) + cos(lat)×cos(δ)×cos(h)
///
/// Reference: Meeus, J. (1991). Astronomical Algorithms. Willmann-Bell.
double _solarElevation(double latitude, DateTime time) {
  final dayOfYear = time.difference(DateTime(time.year, 1, 1)).inDays + 1;
  final hour = time.hour + time.minute / 60.0;

  // Solar declination (angle of sun relative to equator)
  final declination = 23.45 * math.sin(2 * math.pi / 365 * (284 + dayOfYear));

  // Hour angle (sun's position in daily rotation, 0 at solar noon)
  // Simplified: assumes local time ≈ solar time (ignores longitude offset within timezone)
  final hourAngle = 15.0 * (hour - 12);

  // Convert to radians
  final latRad = latitude * math.pi / 180;
  final decRad = declination * math.pi / 180;
  final haRad = hourAngle * math.pi / 180;

  // Solar elevation formula
  final sinElevation = math.sin(latRad) * math.sin(decRad) +
      math.cos(latRad) * math.cos(decRad) * math.cos(haRad);

  return math.asin(sinElevation.clamp(-1.0, 1.0)) * 180 / math.pi;
}

/// Calculate clear-sky illuminance in lux from solar elevation angle.
///
/// Uses atmospheric model accounting for optical path length.
/// Returns ~400-800 lux at sunrise/sunset (0°), ~130,000 lux at zenith (90°).
///
/// Formula from ha-illuminance project, based on atmospheric physics:
/// https://github.com/pnbruckner/ha-illuminance
///
/// Reference: Derived from Kasten & Young (1989) air mass formula
/// and empirical illuminance measurements.
double _clearSkyIlluminance(double elevation) {
  if (elevation < -6) return 0; // Below civil twilight

  final elevRad = elevation * math.pi / 180;
  final u = math.sin(elevRad);

  // Atmospheric refraction constant
  const x = 753.66156;

  // Calculate optical air mass
  final s = math.asin((x * math.cos(elevRad) / (x + 1)).clamp(-1.0, 1.0));
  final m = x * (math.cos(s) - u) + math.cos(s);

  // Illuminance formula with atmospheric extinction
  final factor = math.exp(-0.2 * m) * u +
      0.0289 * math.exp(-0.042 * m) * (1 + (elevation + 90) * u / 57.29577951);

  return 133775 * factor.clamp(0.0, double.infinity);
}

/// Calculate sunshine percentage (0-100) for a given hour.
/// Uses the same model as the sunshine bars.
int _calculateSunshinePercent(HourlyData hourData, double latitude) {
  const maxIlluminance = 130000.0;

  final elevation = _solarElevation(latitude, hourData.time);
  final clearSkyLux = _clearSkyIlluminance(elevation);

  if (clearSkyLux <= 0) return 0;

  final potential = (clearSkyLux / maxIlluminance).clamp(0.0, 1.0);
  final cloudDivisor = math.pow(10, hourData.cloudCover / 100.0);
  final precipDivisor = 1 + 0.5 * math.pow(hourData.precipitation, 0.6);

  final linear = potential / cloudDivisor / precipDivisor;
  return (linear * 100).round();
}

/// Modern meteogram chart with temperature line, precipitation bars, and sky gradient.
class MeteogramChart extends StatefulWidget {
  final List<HourlyData> data;
  final int nowIndex;
  final double latitude;
  final bool compact;
  final String? staleText;
  /// Optional explicit colors (for offscreen rendering with specific theme).
  final MeteogramColors? explicitColors;
  /// Optional explicit locale (for offscreen rendering).
  final String? explicitLocale;

  const MeteogramChart({
    super.key,
    required this.data,
    required this.nowIndex,
    required this.latitude,
    this.compact = false,
    this.staleText,
    this.explicitColors,
    this.explicitLocale,
  });

  @override
  State<MeteogramChart> createState() => _MeteogramChartState();
}

class _MeteogramChartState extends State<MeteogramChart> {
  int? _touchedIndex;

  // Forward widget properties for easier access
  List<HourlyData> get data => widget.data;
  int get nowIndex => widget.nowIndex;
  double get latitude => widget.latitude;
  bool get compact => widget.compact;
  String? get staleText => widget.staleText;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final colors = widget.explicitColors ?? MeteogramColors.of(context);
    final locale = widget.explicitLocale ?? Localizations.localeOf(context).toString();

    // Calculate nowFraction from nowIndex
    // +1 to extend fade zone slightly past the "now" line
    final nowFraction = (nowIndex + 1) / data.length;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.zero,
          // Sky gradient removed - widget uses system background color
          child: Column(
              children: [
                // Tooltip row (fixed position above chart, outside shader mask)
                if (!compact && _touchedIndex != null)
                  _buildFixedTooltip(context, colors, locale),
                // Chart area
                Expanded(
                  child: Stack(
                    children: [
                      // Chart content with past time fade
                      Positioned.fill(
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.white.withAlpha(40),  // 15% at left edge
                                Colors.white.withAlpha(80),  // 30% at 3/4 through past
                                Colors.white,                // 100% at "now"
                                Colors.white,                // 100% for future
                              ],
                              stops: [
                                0.0,
                                nowFraction * 0.75,
                                nowFraction,
                                1.0,
                              ],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.modulate,
                          child: Stack(
                            children: [
                              // Sunshine bars (behind)
                              _buildSunshineBars(colors),
                              // Precipitation bars (in front of sunshine)
                              _buildPrecipitationBars(colors),
                              // Temperature line with gradient fill and now indicator
                              _buildTemperatureChart(colors, locale),
                            ],
                          ),
                        ),
                      ),
                      // Min/max temperature labels (centered in past area)
                      _buildTempLabels(colors, nowFraction),
                    ],
                  ),
                ),
                // Time labels below chart
                SizedBox(
                  height: compact ? 18 : 22,
                  child: _buildTimeLabels(colors, locale),
                ),
              ],
            ),
          ),
        // Stale data watermark (aligned with "now" line)
        if (staleText != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final leftPadding = constraints.maxWidth * nowFraction;
                return Padding(
                  padding: EdgeInsets.only(left: leftPadding),
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.2, // Slight tilt
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            staleText!,
                            style: TextStyle(
                              color: colors.primaryText.withAlpha(40),
                              fontSize: compact ? 32 : 48,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTemperatureChart(MeteogramColors colors, String locale) {
    final minTemp = data.map((d) => d.temperature).reduce((a, b) => a < b ? a : b);
    final maxTemp = data.map((d) => d.temperature).reduce((a, b) => a > b ? a : b);
    final tempRange = maxTemp - minTemp;

    // Add 10% Y padding so temperature line doesn't hit top/bottom edges
    final yPadding = tempRange * 0.10;

    // Use nowIndex for the "now" line position
    final nowPosition = nowIndex.toDouble();

    // Build vertical lines for time labels (12h intervals from now)
    final verticalLines = <VerticalLine>[];
    for (var i = nowIndex; i < data.length - 8; i++) {
      final offset = i - nowIndex;
      if (offset < 0 || offset % 12 != 0) continue;

      if (i == nowIndex) {
        // "Now" line - thicker, uses Material You tertiary color
        verticalLines.add(VerticalLine(
          x: i.toDouble(),
          color: colors.timeLabel,
          strokeWidth: compact ? 2 : 3,
        ));
      } else {
        // Time label lines - thin, uses Material You tertiary color
        verticalLines.add(VerticalLine(
          x: i.toDouble(),
          color: colors.timeLabel.withAlpha(100),
          strokeWidth: 1,
        ));
      }
    }

    return LineChart(
      LineChartData(
        minY: minTemp - yPadding,
        maxY: maxTemp + yPadding,
        extraLinesData: ExtraLinesData(
          verticalLines: verticalLines,
        ),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.temperature);
            }).toList(),
            isCurved: true,
            curveSmoothness: 0.35,
            color: colors.temperatureLine,
            barWidth: compact ? 2.5 : 3.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.temperatureGradientStart,
                  colors.temperatureGradientEnd,
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: !compact,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            // Hide built-in tooltip (we show fixed tooltip below chart)
            getTooltipColor: (_) => Colors.transparent,
            getTooltipItems: (_) => [const LineTooltipItem('', TextStyle())],
          ),
          touchCallback: (event, response) {
            if (compact) return;
            if (event is FlTapUpEvent || event is FlPanEndEvent || event is FlLongPressEnd) {
              setState(() => _touchedIndex = null);
            } else if (response?.lineBarSpots?.isNotEmpty == true) {
              final index = response!.lineBarSpots!.first.x.toInt();
              if (index != _touchedIndex) {
                setState(() => _touchedIndex = index);
              }
            }
          },
        ),
      ),
    );
  }

  /// Fixed tooltip row shown above chart (outside shader mask).
  Widget _buildFixedTooltip(BuildContext context, MeteogramColors colors, String locale) {
    final index = _touchedIndex;
    if (index == null || index < 0 || index >= data.length) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final hourData = data[index];
    final timeStr = DateFormat.j(locale).format(hourData.time);
    final sunshinePercent = _calculateSunshinePercent(hourData, latitude);

    final textStyle = TextStyle(
      color: colors.primaryText,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$timeStr  ${hourData.temperature.round()}°', style: textStyle),
          if (sunshinePercent > 0) ...[
            const SizedBox(width: 12),
            Text('☀', style: TextStyle(color: colors.sunshineBar, fontSize: 13)),
            Text(' $sunshinePercent%', style: textStyle),
          ],
          if (hourData.precipitation > 0) ...[
            const SizedBox(width: 12),
            Text('💧', style: TextStyle(color: colors.precipitationBar, fontSize: 13)),
            Text(' ${l10n.precipitationRate(hourData.precipitation.toStringAsFixed(1))}', style: textStyle),
          ],
        ],
      ),
    );
  }

  /// Builds sunshine bars (yellow, behind precipitation).
  ///
  /// Combines three models:
  ///
  /// 1. **Clear-sky illuminance** - Atmospheric model based on solar elevation,
  ///    accounting for optical air mass and atmospheric extinction.
  ///    Returns ~400-800 lux at sunrise/sunset, ~130,000 lux at zenith.
  ///    Based on Kasten & Young (1989) air mass formula.
  ///
  /// 2. **Cloud attenuation** - ha-illuminance logarithmic model:
  ///    ```
  ///    divisor = 10^(cloudCover/100)
  ///    ```
  ///    At 50% clouds → 32% light, at 100% clouds → 10% light.
  ///
  /// 3. **Precipitation attenuation** - Based on extinction coefficient research:
  ///    ```
  ///    divisor = 1 + 0.5 × R^0.6
  ///    ```
  ///    Where R is precipitation in mm/h. Derived from MOR-rain relationships
  ///    (σ = aR^b) in atmospheric visibility studies.
  ///    At 5mm/h → 40% light, at 10mm/h → 33% light.
  ///
  /// References:
  /// - Kasten, F. & Young, A.T. (1989). "Revised optical air mass tables and
  ///   approximation formula." Applied Optics, 28(22), 4735-4738.
  /// - ha-illuminance: https://github.com/pnbruckner/ha-illuminance
  /// - Rainfall-MOR relationship: https://doi.org/10.20937/ATM.53297
  Widget _buildSunshineBars(MeteogramColors colors) {
    const chartMax = 10.0;
    const maxIlluminance = 130000.0; // Peak clear-sky illuminance in lux

    // Check if there's any potential sunshine (including civil twilight)
    bool hasSunshine = false;
    for (final hourData in data) {
      final elevation = _solarElevation(latitude, hourData.time);
      if (elevation > -6) { // Civil twilight threshold
        hasSunshine = true;
        break;
      }
    }
    if (!hasSunshine) return const SizedBox();

    return Opacity(
      opacity: 0.7,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: chartMax,
          alignment: BarChartAlignment.spaceAround,
          barGroups: data.asMap().entries.map((e) {
            final hourData = e.value;
            final elevation = _solarElevation(latitude, hourData.time);

            // Get clear-sky illuminance (accounts for atmospheric path)
            final clearSkyLux = _clearSkyIlluminance(elevation);
            if (clearSkyLux <= 0) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    fromY: chartMax,
                    toY: chartMax,
                    color: Colors.transparent,
                    width: compact ? 4 : 6,
                  ),
                ],
              );
            }

            // Normalize to 0-1 range
            final potential = (clearSkyLux / maxIlluminance).clamp(0.0, 1.0);

            // ha-illuminance cloud attenuation: divisor = 10^(cloud/100)
            // 0% → 1x, 50% → 3.16x, 100% → 10x reduction
            final cloudDivisor = math.pow(10, hourData.cloudCover / 100.0);

            // Precipitation attenuation based on extinction coefficient research
            // divisor = 1 + 0.5 × R^0.6 where R is mm/h
            // 1mm/h → 1.5x, 5mm/h → 2.5x, 10mm/h → 3x reduction
            final precipDivisor = 1 + 0.5 * math.pow(hourData.precipitation, 0.6);

            final linear = potential / cloudDivisor / precipDivisor;

            // Square root scale to make small values more visible
            // sqrt(x) maps 0->0, 1->1 with gentle curve
            final scaled = math.sqrt(linear);
            final sunshine = scaled * chartMax;

            if (sunshine <= 0) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    fromY: chartMax,
                    toY: chartMax,
                    color: Colors.transparent,
                    width: compact ? 4 : 6,
                  ),
                ],
              );
            }

            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  fromY: chartMax,
                  toY: chartMax - sunshine,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.sunshineGradient,
                      colors.sunshineBar,
                    ],
                  ),
                  width: compact ? 4 : 6,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(3),
                  ),
                ),
              ],
            );
          }).toList(),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
        ),
      ),
    );
  }

  /// Builds precipitation bars (teal, in front of sunshine).
  /// Uses square root scaling to make light rain visible.
  Widget _buildPrecipitationBars(MeteogramColors colors) {
    final maxPrecip = data.map((d) => d.precipitation).reduce((a, b) => a > b ? a : b);
    if (maxPrecip == 0) return const SizedBox();

    const chartMax = 10.0;
    const maxPrecipReference = 10.0; // 10mm/h = heavy rain = full scale

    return Opacity(
      opacity: 0.7,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: chartMax,
          alignment: BarChartAlignment.spaceAround,
          barGroups: data.asMap().entries.map((e) {
            final precip = e.value.precipitation;
            if (precip <= 0) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    fromY: chartMax,
                    toY: chartMax,
                    color: Colors.transparent,
                    width: compact ? 4 : 6,
                  ),
                ],
              );
            }
            // Normalize and apply square root scale (same as sunshine)
            final normalized = (precip / maxPrecipReference).clamp(0.0, 1.0);
            final scaled = math.sqrt(normalized) * chartMax;

            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  fromY: chartMax,
                  toY: chartMax - scaled,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colors.precipitationGradient,
                      colors.precipitationBar,
                    ],
                  ),
                  width: compact ? 4 : 6,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(3),
                  ),
                ),
              ],
            );
          }).toList(),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
        ),
      ),
    );
  }

  Widget _buildTempLabels(MeteogramColors colors, double nowFraction) {
    final minTemp = data.map((d) => d.temperature).reduce((a, b) => a < b ? a : b);
    final maxTemp = data.map((d) => d.temperature).reduce((a, b) => a > b ? a : b);
    final midTemp = (minTemp + maxTemp) / 2;

    // Use temperature line color for visual consistency
    final textStyle = TextStyle(
      color: colors.temperatureLine,
      fontSize: compact ? 11 : 13,
      fontWeight: FontWeight.bold,
    );

    // Padding fraction matches yPadding in _buildTemperatureChart (10% of range)
    // Total range = tempRange + 2*padding = tempRange * 1.2
    // So actual temps are at 10%/120% = 8.33% from edges
    const paddingFraction = 0.10 / 1.20;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Position labels in left portion of the past area
        final centerX = (nowFraction / 2.5) * constraints.maxWidth;
        final topOffset = constraints.maxHeight * paddingFraction;
        final bottomOffset = constraints.maxHeight * paddingFraction;

        return Stack(
          children: [
            // Max temp at top (offset by padding)
            Positioned(
              top: topOffset,
              left: centerX,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Text('${maxTemp.round()}', style: textStyle),
              ),
            ),
            // Mid temp in center
            Positioned(
              top: 0,
              bottom: 0,
              left: centerX,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
                child: Center(
                  child: Text('${midTemp.round()}', style: textStyle),
                ),
              ),
            ),
            // Min temp at bottom (offset by padding)
            Positioned(
              bottom: bottomOffset,
              left: centerX,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0.5),
                child: Text('${minTemp.round()}', style: textStyle),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeLabels(MeteogramColors colors, String locale) {
    // Use nowIndex for label positioning

    // Use Material You tertiary color for time labels (distinct from temperature)
    final textStyle = TextStyle(
      color: colors.timeLabel,
      fontSize: compact ? 11 : 13,
      fontWeight: FontWeight.w600,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final labels = <Widget>[];

        for (var i = 0; i < data.length; i++) {
          // Show labels at: now, now+12h, now+24h, etc.
          final offset = i - nowIndex;
          if (offset < 0 || offset % 12 != 0) continue;
          if (i > data.length - 8) continue; // Skip last label

          final time = data[i].time;
          final timeStr = DateFormat.j(locale).format(time);
          final xPos = (i / (data.length - 1)) * width;

          labels.add(
            Positioned(
              left: xPos,
              top: 0,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
                child: Text(timeStr, style: textStyle),
              ),
            ),
          );
        }

        return Stack(children: labels);
      },
    );
  }

}
