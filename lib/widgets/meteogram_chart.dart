import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/weather_data.dart';
import '../theme/app_theme.dart';

/// Meteogram chart displaying temperature, precipitation, and cloud cover.
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

    return CustomPaint(
      painter: _CloudBackgroundPainter(
        data: data,
        colors: colors,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: compact ? 4 : 8,
          right: compact ? 4 : 8,
          top: compact ? 4 : 8,
          bottom: compact ? 16 : 24,
        ),
        child: Stack(
          children: [
            // Precipitation bars (behind temperature line)
            _buildPrecipitationBars(colors),
            // Temperature line chart
            _buildTemperatureChart(colors, now),
            // Now indicator (uses Row with flex, not Positioned)
            _buildNowIndicator(colors, now),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureChart(MeteogramColors colors, DateTime now) {
    final minTemp = data.map((d) => d.temperature).reduce((a, b) => a < b ? a : b);
    final maxTemp = data.map((d) => d.temperature).reduce((a, b) => a > b ? a : b);
    final tempRange = maxTemp - minTemp;
    final padding = tempRange * 0.1;

    return LineChart(
      LineChartData(
        minY: minTemp - padding,
        maxY: maxTemp + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _calculateInterval(tempRange),
          getDrawingHorizontalLine: (value) => FlLine(
            color: colors.gridLine.withOpacity(0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !compact,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text(
                '${value.round()}°',
                style: TextStyle(
                  color: colors.labelText,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: compact ? 16 : 20,
              interval: _calculateTimeInterval(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox();
                final hour = data[index].time.hour;
                return Text(
                  '$hour:00',
                  style: TextStyle(
                    color: colors.labelText,
                    fontSize: compact ? 8 : 10,
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
            curveSmoothness: 0.3,
            color: colors.temperatureLine,
            barWidth: compact ? 2 : 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: !compact,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final hourData = data[spot.x.toInt()];
                return LineTooltipItem(
                  '${hourData.temperature.round()}°\n${hourData.time.hour}:00',
                  TextStyle(color: colors.temperatureLine),
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

    return BarChart(
      BarChartData(
        maxY: maxPrecip * 1.2,
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.precipitation,
                color: colors.precipitationBar.withOpacity(0.6),
                width: compact ? 3 : 5,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              ),
            ],
          );
        }).toList(),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
      ),
    );
  }

  Widget _buildNowIndicator(MeteogramColors colors, DateTime now) {
    // Find the index closest to now
    int? nowIndex;
    for (var i = 0; i < data.length; i++) {
      if (data[i].time.hour == now.hour && data[i].time.day == now.day) {
        nowIndex = i;
        break;
      }
    }

    if (nowIndex == null || data.length <= 1) return const SizedBox();

    // Use flex-based positioning to avoid Positioned/LayoutBuilder conflict
    final fraction = nowIndex / (data.length - 1);
    final leftFlex = (fraction * 1000).round().clamp(1, 999);
    final rightFlex = ((1 - fraction) * 1000).round().clamp(1, 999);

    return Row(
      children: [
        Expanded(
          flex: leftFlex,
          child: const SizedBox(),
        ),
        Container(
          width: 2,
          color: colors.nowIndicator,
        ),
        Expanded(
          flex: rightFlex,
          child: const SizedBox(),
        ),
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
    if (data.length <= 12) return 2;
    if (data.length <= 24) return 4;
    return 6;
  }
}

/// Custom painter for cloud cover background gradient.
class _CloudBackgroundPainter extends CustomPainter {
  final List<HourlyData> data;
  final MeteogramColors colors;

  _CloudBackgroundPainter({
    required this.data,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final segmentWidth = size.width / data.length;

    for (var i = 0; i < data.length; i++) {
      final rect = Rect.fromLTWH(
        i * segmentWidth,
        0,
        segmentWidth + 1, // +1 to avoid gaps
        size.height,
      );

      final paint = Paint()
        ..color = colors.getSkyColor(data[i].cloudCover).withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CloudBackgroundPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}
