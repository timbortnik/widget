import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 12 : 20),
      child: CustomPaint(
        painter: _SkyGradientPainter(data: data, colors: colors),
        child: Padding(
          padding: EdgeInsets.only(
            left: compact ? 8 : 16,
            right: compact ? 8 : 16,
            top: compact ? 8 : 16,
            bottom: compact ? 20 : 32,
          ),
          child: Stack(
            children: [
              // Precipitation bars (behind)
              _buildPrecipitationBars(colors),
              // Temperature line with gradient fill
              _buildTemperatureChart(colors, now),
              // Current time indicator
              _buildNowIndicator(colors, now),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTemperatureChart(MeteogramColors colors, DateTime now) {
    final minTemp = data.map((d) => d.temperature).reduce((a, b) => a < b ? a : b);
    final maxTemp = data.map((d) => d.temperature).reduce((a, b) => a > b ? a : b);
    final tempRange = maxTemp - minTemp;
    final padding = (tempRange * 0.15).clamp(2.0, 10.0);

    return LineChart(
      LineChartData(
        minY: minTemp - padding,
        maxY: maxTemp + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(tempRange),
          getDrawingHorizontalLine: (value) => FlLine(
            color: colors.gridLine,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !compact,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                if (value == meta.min || value == meta.max) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${value.round()}°',
                    style: TextStyle(
                      color: colors.labelText,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: compact ? 20 : 28,
              interval: _calculateTimeInterval(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox();
                final hour = data[index].time.hour;
                final isNow = data[index].time.hour == now.hour &&
                              data[index].time.day == now.day;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    hour == 0 ? '12am' : hour == 12 ? '12pm' :
                    hour > 12 ? '${hour - 12}pm' : '${hour}am',
                    style: TextStyle(
                      color: isNow ? colors.nowIndicator : colors.labelText,
                      fontSize: compact ? 9 : 11,
                      fontWeight: isNow ? FontWeight.bold : FontWeight.w500,
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
            dotData: FlDotData(
              show: !compact,
              getDotPainter: (spot, percent, barData, index) {
                final isNow = data[index].time.hour == now.hour &&
                              data[index].time.day == now.day;
                return FlDotCirclePainter(
                  radius: isNow ? 5 : 0,
                  color: colors.nowIndicator,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
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

    return Opacity(
      opacity: 0.7,
      child: BarChart(
        BarChartData(
          maxY: maxPrecip * 1.5,
          alignment: BarChartAlignment.spaceAround,
          barGroups: data.asMap().entries.map((e) {
            final hasPrecip = e.value.precipitation > 0;
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.precipitation,
                  gradient: hasPrecip ? LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      colors.precipitationBar,
                      colors.precipitationGradient,
                    ],
                  ) : null,
                  color: hasPrecip ? null : Colors.transparent,
                  width: compact ? 4 : 6,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
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

  Widget _buildNowIndicator(MeteogramColors colors, DateTime now) {
    int? nowIndex;
    for (var i = 0; i < data.length; i++) {
      if (data[i].time.hour == now.hour && data[i].time.day == now.day) {
        nowIndex = i;
        break;
      }
    }

    if (nowIndex == null || data.length <= 1) return const SizedBox();

    final fraction = nowIndex / (data.length - 1);
    final leftFlex = (fraction * 1000).round().clamp(1, 999);
    final rightFlex = ((1 - fraction) * 1000).round().clamp(1, 999);

    return Row(
      children: [
        Expanded(flex: leftFlex, child: const SizedBox()),
        Container(
          width: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.nowIndicator,
                colors.nowIndicator.withAlpha(100),
              ],
            ),
            borderRadius: BorderRadius.circular(1),
            boxShadow: [
              BoxShadow(
                color: colors.nowIndicator.withAlpha(80),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        Expanded(flex: rightFlex, child: const SizedBox()),
      ],
    );
  }

  double _calculateInterval(double range) {
    if (range <= 5) return 1;
    if (range <= 10) return 2;
    if (range <= 20) return 5;
    return 10;
  }

  double _calculateTimeInterval() {
    if (data.length <= 12) return 3;
    if (data.length <= 24) return 6;
    return 8;
  }
}

/// Custom painter for smooth sky gradient background based on cloud cover.
class _SkyGradientPainter extends CustomPainter {
  final List<HourlyData> data;
  final MeteogramColors colors;

  _SkyGradientPainter({required this.data, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Create smooth gradient across all data points
    final gradientColors = <Color>[];
    final stops = <double>[];

    for (var i = 0; i < data.length; i++) {
      gradientColors.add(colors.getSkyColor(data[i].cloudCover).withAlpha(60));
      stops.add(i / (data.length - 1));
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
