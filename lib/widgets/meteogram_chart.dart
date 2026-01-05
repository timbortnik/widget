import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weather_data.dart';
import '../theme/app_theme.dart';

/// Calculate solar elevation angle in degrees.
/// Returns negative values when sun is below horizon.
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

/// Modern meteogram chart with temperature line, precipitation bars, and sky gradient.
class MeteogramChart extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final colors = explicitColors ?? MeteogramColors.of(context);
    final locale = explicitLocale ?? Localizations.localeOf(context).toString();

    // Calculate nowFraction from nowIndex
    // +1 to extend fade zone slightly past the "now" line
    final nowFraction = (nowIndex + 1) / data.length;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 12 : 20),
          child: CustomPaint(
            painter: _SkyGradientPainter(data: data, colors: colors, nowFraction: nowFraction),
            child: Column(
              children: [
                // Chart area
                Expanded(
                  child: Stack(
                    children: [
                      // Chart content with fade effect for past
                      Positioned.fill(
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            // Non-linear fade: stays faded longer, then ramps up quickly
                            return LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: const [
                                Color(0x1AFFFFFF), // 10% at left edge
                                Color(0x40FFFFFF), // 25% at 3/4 of past
                                Color(0xFFFFFFFF), // 100% at "now"
                                Color(0xFFFFFFFF), // 100% for future
                              ],
                              stops: [
                                0.0,
                                nowFraction * 0.75,
                                nowFraction,
                                1.0,
                              ],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
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
                      // Min/max temperature labels (not faded, centered in past area)
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

    // Add Y padding so graph min/max align with center of temperature labels
    // Labels are fontSize/2 from edge, roughly 5-6% of chart height
    final yPadding = tempRange * 0.06;

    // Use nowIndex for the "now" line position
    final nowPosition = nowIndex.toDouble();

    // Build vertical lines for time labels (12h intervals from now)
    final verticalLines = <VerticalLine>[];
    for (var i = nowIndex; i < data.length - 8; i++) {
      final offset = i - nowIndex;
      if (offset < 0 || offset % 12 != 0) continue;

      if (i == nowIndex) {
        // "Now" line - thicker
        verticalLines.add(VerticalLine(
          x: i.toDouble(),
          color: colors.labelText,
          strokeWidth: compact ? 2 : 3,
        ));
      } else {
        // Time label lines - thin
        verticalLines.add(VerticalLine(
          x: i.toDouble(),
          color: colors.labelText.withAlpha(100),
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
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 12,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final hourData = data[spot.x.toInt()];
                final hour = hourData.time.hour;
                final timeStr = hour == 0 ? '12am' : hour == 12 ? '12pm' :
                               hour > 12 ? '${hour - 12}pm' : '${hour}am';
                return LineTooltipItem(
                  '${hourData.temperature.round()}°\n$timeStr',
                  TextStyle(
                    color: colors.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  /// Builds sunshine bars (yellow, behind precipitation).
  /// Uses astronomical solar elevation combined with cloud cover.
  Widget _buildSunshineBars(MeteogramColors colors) {
    const chartMax = 10.0;
    const maxElevation = 90.0; // Maximum possible solar elevation

    // Check if there's any potential sunshine
    bool hasSunshine = false;
    for (final hourData in data) {
      final elevation = _solarElevation(latitude, hourData.time);
      if (elevation > 0 && hourData.cloudCover < 100) {
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

            // Sun below horizon = no sunshine
            if (elevation <= 0) {
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

            // Potential sunshine from sun elevation (0-90° maps to 0-1)
            final potential = (elevation / maxElevation).clamp(0.0, 1.0);

            // Actual sunshine reduced by cloud cover
            final clearSkyFactor = (100 - hourData.cloudCover) / 100.0;
            final sunshine = potential * clearSkyFactor * chartMax;

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
  Widget _buildPrecipitationBars(MeteogramColors colors) {
    final maxPrecip = data.map((d) => d.precipitation).reduce((a, b) => a > b ? a : b);
    if (maxPrecip == 0) return const SizedBox();

    const chartMax = 10.0;

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
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  fromY: chartMax,
                  toY: chartMax - precip,
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
      fontSize: compact ? 15 : 18,
      fontWeight: FontWeight.bold,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Position labels in left portion of the past area
        final centerX = (nowFraction / 2.5) * constraints.maxWidth;
        return Stack(
          children: [
            // Max temp at top
            Positioned(
              top: 0,
              left: centerX,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
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
            // Min temp at bottom
            Positioned(
              bottom: 0,
              left: centerX,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0),
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

    // Adaptive color - uses theme-aware labelText (dark on light bg, light on dark bg)
    final textStyle = TextStyle(
      color: colors.labelText,
      fontSize: compact ? 14 : 16,
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

/// Custom painter for smooth sky gradient background based on cloud cover.
class _SkyGradientPainter extends CustomPainter {
  final List<HourlyData> data;
  final MeteogramColors colors;
  final double nowFraction;

  _SkyGradientPainter({
    required this.data,
    required this.colors,
    required this.nowFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Create smooth gradient across all data points with fade for past
    final gradientColors = <Color>[];
    final stops = <double>[];

    for (var i = 0; i < data.length; i++) {
      final stop = i / (data.length - 1);
      // Fade past portion (before nowFraction)
      final fadeFactor = stop < nowFraction
          ? stop / nowFraction  // 0 at left edge, 1 at now
          : 1.0;
      final alpha = (60 * fadeFactor).round();
      gradientColors.add(colors.getSkyColor(data[i].cloudCover).withAlpha(alpha));
      stops.add(stop);
    }

    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: gradientColors,
      stops: stops,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    // Draw with rounded corners
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _SkyGradientPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
