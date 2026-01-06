import 'dart:math' as math;
import '../models/weather_data.dart';

/// SVG color representation (no dart:ui Color dependency).
/// This allows the generator to work in background isolates without dart:ui.
class SvgColor {
  final int r, g, b, a;
  const SvgColor(this.r, this.g, this.b, [this.a = 255]);

  /// Convert to hex color string (#RRGGBB).
  String toHex() => '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}';

  /// Get opacity as 0.0-1.0 value.
  double get opacity => a / 255.0;
}

/// Chart colors for SVG generation.
class SvgChartColors {
  final SvgColor temperatureLine;
  final SvgColor temperatureGradientStart;
  final SvgColor temperatureGradientEnd;
  final SvgColor precipitationBar;
  final SvgColor precipitationGradient;
  final SvgColor sunshineBar;
  final SvgColor sunshineGradient;
  final SvgColor nowIndicator;
  final SvgColor timeLabel;
  final SvgColor cardBackground;
  final SvgColor primaryText;

  const SvgChartColors({
    required this.temperatureLine,
    required this.temperatureGradientStart,
    required this.temperatureGradientEnd,
    required this.precipitationBar,
    required this.precipitationGradient,
    required this.sunshineBar,
    required this.sunshineGradient,
    required this.nowIndicator,
    required this.timeLabel,
    required this.cardBackground,
    required this.primaryText,
  });

  static const light = SvgChartColors(
    temperatureLine: SvgColor(0xFF, 0x6B, 0x6B),
    temperatureGradientStart: SvgColor(0xFF, 0x6B, 0x6B, 0x40),
    temperatureGradientEnd: SvgColor(0xFF, 0x6B, 0x6B, 0x00),
    precipitationBar: SvgColor(0x4E, 0xCD, 0xC4),
    precipitationGradient: SvgColor(0x4E, 0xCD, 0xC4, 0x80),
    sunshineBar: SvgColor(0xFF, 0xF0, 0xAA),
    sunshineGradient: SvgColor(0xFF, 0xD5, 0x80),
    nowIndicator: SvgColor(0x4A, 0x55, 0x68),
    timeLabel: SvgColor(0x4A, 0x55, 0x68),
    cardBackground: SvgColor(0xFF, 0xFF, 0xFF),
    primaryText: SvgColor(0x2D, 0x34, 0x36),
  );

  static const dark = SvgChartColors(
    temperatureLine: SvgColor(0xFF, 0x76, 0x75),
    temperatureGradientStart: SvgColor(0xFF, 0x76, 0x75, 0x60),
    temperatureGradientEnd: SvgColor(0xFF, 0x76, 0x75, 0x00),
    precipitationBar: SvgColor(0x00, 0xCE, 0xC9),
    precipitationGradient: SvgColor(0x00, 0xCE, 0xC9, 0x80),
    sunshineBar: SvgColor(0xFF, 0xF0, 0xAA),
    sunshineGradient: SvgColor(0xFF, 0xD0, 0x80),
    nowIndicator: SvgColor(0xE0, 0xE0, 0xE0),
    timeLabel: SvgColor(0xE0, 0xE0, 0xE0),
    cardBackground: SvgColor(0x1B, 0x28, 0x38),
    primaryText: SvgColor(0xFF, 0xFF, 0xFF),
  );
}

/// Generates SVG meteogram charts for background widget updates.
class SvgChartGenerator {
  /// Format number as integer for flutter_svg compatibility.
  String _n(double v) => v.round().toString();

  String generate({
    required List<HourlyData> data,
    required int nowIndex,
    required double latitude,
    required SvgChartColors colors,
    required double width,
    required double height,
    bool useMask = true,
  }) {
    if (data.isEmpty) {
      return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${_n(width)} ${_n(height)}"><rect width="100%" height="100%" fill="${colors.cardBackground.toHex()}"/></svg>';
    }

    final svg = StringBuffer();
    final chartHeight = height - 22;
    final nowFraction = (nowIndex + 1) / data.length;

    svg.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${_n(width)} ${_n(height)}">');

    // Background
    svg.write('<rect width="100%" height="100%" fill="${colors.cardBackground.toHex()}"/>');

    // Chart group
    svg.write('<g>');

    // Sunshine bars
    _writeSunshineBars(svg, data, latitude, colors, width, chartHeight);

    // Precipitation bars
    _writePrecipitationBars(svg, data, colors, width, chartHeight);

    // Temperature line
    _writeTemperatureLine(svg, data, colors, width, chartHeight);

    // Now indicator
    final nowX = (nowIndex / (data.length - 1)) * width;
    svg.write('<line x1="${_n(nowX)}" y1="0" x2="${_n(nowX)}" y2="${_n(chartHeight)}" stroke="${colors.nowIndicator.toHex()}" stroke-width="3"/>');

    // Grid lines
    for (var i = nowIndex + 12; i < data.length - 8; i += 12) {
      final x = (i / (data.length - 1)) * width;
      svg.write('<line x1="${_n(x)}" y1="0" x2="${_n(x)}" y2="${_n(chartHeight)}" stroke="${colors.timeLabel.toHex()}" stroke-width="1" opacity="0.4"/>');
    }

    svg.write('</g>');

    // Temperature labels
    _writeTempLabels(svg, data, colors, width, chartHeight, nowFraction);

    // Time labels
    _writeTimeLabels(svg, data, nowIndex, colors, width, height);

    svg.write('</svg>');
    return svg.toString();
  }

  void _writeSunshineBars(StringBuffer svg, List<HourlyData> data,
      double latitude, SvgChartColors colors, double width, double chartHeight) {
    final slotWidth = width / data.length;
    final barWidth = slotWidth * 0.7;

    svg.write('<g opacity="0.7">');
    for (var i = 0; i < data.length; i++) {
      final sunshine = _calculateSunshine(data[i], latitude);
      if (sunshine <= 0) continue;

      final barHeight = sunshine * chartHeight;
      final x = i * slotWidth + (slotWidth - barWidth) / 2;

      svg.write('<rect x="${_n(x)}" y="0" width="${_n(barWidth)}" height="${_n(barHeight)}" fill="${colors.sunshineBar.toHex()}" rx="3"/>');
    }
    svg.write('</g>');
  }

  void _writePrecipitationBars(StringBuffer svg, List<HourlyData> data,
      SvgChartColors colors, double width, double chartHeight) {
    final maxPrecip = data.map((d) => d.precipitation).reduce((a, b) => a > b ? a : b);
    if (maxPrecip == 0) return;

    final slotWidth = width / data.length;
    final barWidth = slotWidth * 0.7;

    svg.write('<g opacity="0.7">');
    for (var i = 0; i < data.length; i++) {
      final precip = data[i].precipitation;
      if (precip <= 0) continue;

      final normalized = (precip / 10.0).clamp(0.0, 1.0);
      final barHeight = math.sqrt(normalized) * chartHeight;
      final x = i * slotWidth + (slotWidth - barWidth) / 2;

      svg.write('<rect x="${_n(x)}" y="0" width="${_n(barWidth)}" height="${_n(barHeight)}" fill="${colors.precipitationBar.toHex()}" rx="3"/>');
    }
    svg.write('</g>');
  }

  void _writeTemperatureLine(StringBuffer svg, List<HourlyData> data,
      SvgChartColors colors, double width, double chartHeight) {
    final temps = data.map((d) => d.temperature).toList();
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    final tempRange = (maxTemp - minTemp).clamp(1.0, double.infinity);
    final yPadding = tempRange * 0.10;

    final points = <List<double>>[];
    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * width;
      final normalizedTemp = (data[i].temperature - minTemp + yPadding) / (tempRange + 2 * yPadding);
      final y = chartHeight * (1 - normalizedTemp);
      points.add([x, y]);
    }

    // Build path
    final path = StringBuffer('M ${_n(points[0][0])} ${_n(points[0][1])}');
    for (var i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final dx = p1[0] - p0[0];
      final cp1x = p0[0] + dx * 0.35;
      final cp2x = p1[0] - dx * 0.35;
      path.write(' C ${_n(cp1x)} ${_n(p0[1])} ${_n(cp2x)} ${_n(p1[1])} ${_n(p1[0])} ${_n(p1[1])}');
    }

    // Area fill
    final areaPath = '$path L ${_n(width)} ${_n(chartHeight)} L 0 ${_n(chartHeight)} Z';
    svg.write('<path d="$areaPath" fill="${colors.temperatureGradientStart.toHex()}" fill-opacity="${colors.temperatureGradientStart.opacity.toStringAsFixed(2)}" stroke="none"/>');

    // Line
    svg.write('<path d="$path" fill="none" stroke="${colors.temperatureLine.toHex()}" stroke-width="3" stroke-linecap="round"/>');
  }

  void _writeTempLabels(StringBuffer svg, List<HourlyData> data,
      SvgChartColors colors, double width, double chartHeight, double nowFraction) {
    final temps = data.map((d) => d.temperature).toList();
    final minTemp = temps.reduce((a, b) => a < b ? a : b);
    final maxTemp = temps.reduce((a, b) => a > b ? a : b);
    final midTemp = (minTemp + maxTemp) / 2;

    final centerX = (nowFraction / 2.5) * width;
    final topY = chartHeight * 0.083 + 4;
    final midY = chartHeight / 2;
    final bottomY = chartHeight * 0.917 - 4;

    final style = 'fill="${colors.temperatureLine.toHex()}" font-size="13" font-weight="bold" font-family="sans-serif" text-anchor="middle"';

    svg.write('<text x="${_n(centerX)}" y="${_n(topY)}" $style>${maxTemp.round()}</text>');
    svg.write('<text x="${_n(centerX)}" y="${_n(midY)}" $style dominant-baseline="middle">${midTemp.round()}</text>');
    svg.write('<text x="${_n(centerX)}" y="${_n(bottomY)}" $style>${minTemp.round()}</text>');
  }

  void _writeTimeLabels(StringBuffer svg, List<HourlyData> data, int nowIndex,
      SvgChartColors colors, double width, double height) {
    final labelY = height - 6;
    final style = 'fill="${colors.timeLabel.toHex()}" font-size="13" font-weight="600" font-family="sans-serif" text-anchor="middle"';

    for (var i = nowIndex; i < data.length - 8; i++) {
      final offset = i - nowIndex;
      if (offset < 0 || offset % 12 != 0) continue;

      final hour = data[i].time.hour;
      final timeStr = hour == 0 ? '12AM' : hour == 12 ? '12PM' : hour < 12 ? '${hour}AM' : '${hour - 12}PM';
      final x = (i / (data.length - 1)) * width;

      svg.write('<text x="${_n(x)}" y="${_n(labelY)}" $style>$timeStr</text>');
    }
  }

  double _solarElevation(double latitude, DateTime time) {
    final dayOfYear = time.difference(DateTime(time.year, 1, 1)).inDays + 1;
    final hour = time.hour + time.minute / 60.0;
    final declination = 23.45 * math.sin(2 * math.pi / 365 * (284 + dayOfYear));
    final hourAngle = 15.0 * (hour - 12);
    final latRad = latitude * math.pi / 180;
    final decRad = declination * math.pi / 180;
    final haRad = hourAngle * math.pi / 180;
    final sinElevation = math.sin(latRad) * math.sin(decRad) + math.cos(latRad) * math.cos(decRad) * math.cos(haRad);
    return math.asin(sinElevation.clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  double _clearSkyIlluminance(double elevation) {
    if (elevation < -6) return 0;
    final elevRad = elevation * math.pi / 180;
    final u = math.sin(elevRad);
    const x = 753.66156;
    final s = math.asin((x * math.cos(elevRad) / (x + 1)).clamp(-1.0, 1.0));
    final m = x * (math.cos(s) - u) + math.cos(s);
    final factor = math.exp(-0.2 * m) * u + 0.0289 * math.exp(-0.042 * m) * (1 + (elevation + 90) * u / 57.29577951);
    return 133775 * factor.clamp(0.0, double.infinity);
  }

  double _calculateSunshine(HourlyData data, double latitude) {
    final elevation = _solarElevation(latitude, data.time);
    final clearSkyLux = _clearSkyIlluminance(elevation);
    if (clearSkyLux <= 0) return 0;
    final potential = (clearSkyLux / 130000.0).clamp(0.0, 1.0);
    final cloudDivisor = math.pow(10, data.cloudCover / 100.0);
    final precipDivisor = 1 + 0.5 * math.pow(data.precipitation, 0.6);
    return math.sqrt(potential / cloudDivisor / precipDivisor);
  }
}
