import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weather_data.dart';
import '../theme/app_theme.dart';

/// Modern meteogram chart with temperature line, precipitation bars, and sky gradient.
class MeteogramChart extends StatelessWidget {
  final List<HourlyData> data;
  final bool compact;

  const MeteogramChart({
    super.key,
    required this.data,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final colors = MeteogramColors.of(context);
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toString();

    // Find "now" position for fade effect
    // Add small offset to compensate for chart's internal margins
    double nowFraction = 0;
    for (var i = 0; i < data.length; i++) {
      if (data[i].time.hour == now.hour && data[i].time.day == now.day) {
        nowFraction = (i + 1) / data.length;  // +1 to extend fade zone
        break;
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 12 : 20),
      child: CustomPaint(
        painter: _SkyGradientPainter(data: data, colors: colors, nowFraction: nowFraction),
        child: Stack(
            children: [
              // Chart content with fade effect for past
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: const [
                        Color(0x00FFFFFF), // 0% opacity at left edge
                        Color(0xFFFFFFFF), // 100% opacity at "now"
                        Color(0xFFFFFFFF), // 100% opacity for future
                      ],
                      stops: [0.0, nowFraction, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Stack(
                    children: [
                      // Precipitation bars (behind)
                      _buildPrecipitationBars(colors),
                      // Temperature line with gradient fill and now indicator
                      _buildTemperatureChart(colors, now, locale),
                    ],
                  ),
                ),
              ),
              // Min/max temperature labels (not faded)
              _buildTempLabels(colors),
            ],
        ),
      ),
    );
  }

  Widget _buildTemperatureChart(MeteogramColors colors, DateTime now, String locale) {
    final minTemp = data.map((d) => d.temperature).reduce((a, b) => a < b ? a : b);
    final maxTemp = data.map((d) => d.temperature).reduce((a, b) => a > b ? a : b);
    final tempRange = maxTemp - minTemp;

    // Add Y padding so graph min/max align with center of temperature labels
    // Labels are fontSize/2 from edge, roughly 5-6% of chart height
    final yPadding = tempRange * 0.06;

    // Find current time position (aligned to hour for label alignment)
    double? nowPosition;
    for (var i = 0; i < data.length; i++) {
      if (data[i].time.hour == now.hour && data[i].time.day == now.day) {
        nowPosition = i.toDouble();
        break;
      }
    }

    return LineChart(
      LineChartData(
        minY: minTemp - yPadding,
        maxY: maxTemp + yPadding,
        extraLinesData: ExtraLinesData(
          verticalLines: nowPosition != null
              ? [
                  VerticalLine(
                    x: nowPosition,
                    color: colors.labelText,
                    strokeWidth: compact ? 2 : 3,
                    dashArray: null,
                  ),
                ]
              : [],
        ),
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: compact ? 28 : 36,
              interval: 1, // Check every hour, filter in callback
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox();

                // Find "now" index
                int nowIdx = 0;
                for (var i = 0; i < data.length; i++) {
                  if (data[i].time.hour == now.hour && data[i].time.day == now.day) {
                    nowIdx = i;
                    break;
                  }
                }

                // Show labels at: now, now+12h, now+24h, etc.
                // Skip if too close to start (past data) or end of chart
                final offset = index - nowIdx;
                if (offset < 0 || offset % 12 != 0) return const SizedBox();
                if (index > data.length - 8) return const SizedBox(); // Skip last label

                // Show hour from data (not calculated time)
                final time = data[index].time;
                // Use locale-aware hour format
                final timeStr = DateFormat.j(locale).format(time);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      color: colors.labelText,
                      fontSize: compact ? 18 : 21,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
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

  Widget _buildPrecipitationBars(MeteogramColors colors) {
    final maxPrecip = data.map((d) => d.precipitation).reduce((a, b) => a > b ? a : b);
    if (maxPrecip == 0) return const SizedBox();

    // Fixed scale 0-50 mm/h (heavy rain threshold)
    const chartMax = 50.0;

    return Opacity(
      opacity: 0.7,
      child: BarChart(
        BarChartData(
          minY: 0,
          maxY: chartMax,
          alignment: BarChartAlignment.spaceAround,
          barGroups: data.asMap().entries.map((e) {
            final hasPrecip = e.value.precipitation > 0;
            // Bars hang from top (like rain falling from sky)
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  fromY: chartMax, // Start from top
                  toY: chartMax - e.value.precipitation, // Extend downward
                  gradient: hasPrecip
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colors.precipitationGradient,
                            colors.precipitationBar,
                          ],
                        )
                      : null,
                  color: hasPrecip ? null : Colors.transparent,
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

  Widget _buildTempLabels(MeteogramColors colors) {
    final minTemp = data.map((d) => d.temperature).reduce((a, b) => a < b ? a : b);
    final maxTemp = data.map((d) => d.temperature).reduce((a, b) => a > b ? a : b);

    // Use temperature line color for visual consistency
    final textStyle = TextStyle(
      color: colors.temperatureLine,
      fontSize: compact ? 20 : 24,
      fontWeight: FontWeight.bold,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const leftOffset = 0.0;
        return Stack(
          children: [
            // Max temp at top
            Positioned(
              top: 0,
              left: leftOffset,
              child: Text('${maxTemp.round()}', style: textStyle),
            ),
            // Min temp at bottom (above time axis)
            Positioned(
              bottom: compact ? 28 : 36,
              left: leftOffset,
              child: Text('${minTemp.round()}', style: textStyle),
            ),
          ],
        );
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
