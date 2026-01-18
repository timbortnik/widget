package org.bortnik.meteogram

import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.pow
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * SVG color representation for chart generation.
 */
data class SvgColor(
    val r: Int,
    val g: Int,
    val b: Int,
    val a: Int = 255
) {
    /**
     * Convert to hex color string (#RRGGBB).
     */
    fun toHex(): String = "#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}"

    /**
     * Get opacity as 0.0-1.0 value.
     */
    val opacity: Double get() = a / 255.0

    companion object {
        /**
         * Create from ARGB int value (e.g., Android Color.toArgb()).
         */
        fun fromArgb(argb: Int): SvgColor = SvgColor(
            r = (argb shr 16) and 0xFF,
            g = (argb shr 8) and 0xFF,
            b = argb and 0xFF,
            a = (argb shr 24) and 0xFF
        )
    }
}

/**
 * Chart colors for SVG generation.
 */
data class SvgChartColors(
    val temperatureLine: SvgColor,
    val temperatureGradientStart: SvgColor,
    val temperatureGradientEnd: SvgColor,
    val precipitationBar: SvgColor,
    val daylightBar: SvgColor,
    val nowIndicator: SvgColor,
    val timeLabel: SvgColor,
    val cardBackground: SvgColor,
    val primaryText: SvgColor
) {
    /**
     * Create colors with custom temperature line and time label colors.
     * Used to apply Material You dynamic colors.
     */
    fun withDynamicColors(temperatureLine: SvgColor, timeLabel: SvgColor): SvgChartColors = copy(
        temperatureLine = temperatureLine,
        temperatureGradientStart = SvgColor(
            temperatureLine.r,
            temperatureLine.g,
            temperatureLine.b,
            temperatureGradientStart.a
        ),
        temperatureGradientEnd = SvgColor(
            temperatureLine.r,
            temperatureLine.g,
            temperatureLine.b,
            0x00
        ),
        timeLabel = timeLabel
    )

    companion object {
        val light = SvgChartColors(
            temperatureLine = SvgColor(0xFF, 0x6B, 0x6B),
            temperatureGradientStart = SvgColor(0xFF, 0x6B, 0x6B, 0x40),
            temperatureGradientEnd = SvgColor(0xFF, 0x6B, 0x6B, 0x00),
            precipitationBar = SvgColor(0x4E, 0xCD, 0xC4),
            daylightBar = SvgColor(0xFF, 0x8F, 0x00),      // Dark amber (visible on white)
            nowIndicator = SvgColor(0x4A, 0x55, 0x68),
            timeLabel = SvgColor(0x4A, 0x55, 0x68),
            cardBackground = SvgColor(0xFF, 0xFF, 0xFF),
            primaryText = SvgColor(0x2D, 0x34, 0x36)
        )

        val dark = SvgChartColors(
            temperatureLine = SvgColor(0xFF, 0x76, 0x75),
            temperatureGradientStart = SvgColor(0xFF, 0x76, 0x75, 0x28),  // 16% opacity (was 38%)
            temperatureGradientEnd = SvgColor(0xFF, 0x76, 0x75, 0x00),
            precipitationBar = SvgColor(0x00, 0xCE, 0xC9),
            daylightBar = SvgColor(0xFF, 0xD5, 0x4F),        // Warm amber
            nowIndicator = SvgColor(0xFF, 0xFF, 0xFF),        // Pure white
            timeLabel = SvgColor(0xE0, 0xE0, 0xE0),
            cardBackground = SvgColor(0x2D, 0x2D, 0x2D),    // Neutral gray
            primaryText = SvgColor(0xFF, 0xFF, 0xFF)
        )
    }
}

/**
 * Hourly weather data for chart generation.
 */
data class HourlyData(
    val time: Long,           // UTC timestamp in milliseconds
    val temperature: Double,  // Celsius
    val precipitation: Double, // mm
    val cloudCover: Int       // 0-100
)

/**
 * Chart visual constants for SVG generation.
 */
object ChartConstants {
    /** Time label font size as ratio of chart width (4% of width). */
    const val TIME_FONT_SIZE_RATIO = 0.04

    /** Temperature label font size as ratio of chart width (4.5% of width). */
    const val TEMP_FONT_SIZE_RATIO = 0.045

    /** Bar width as ratio of slot width (70% of available space). */
    const val BAR_WIDTH_RATIO = 0.7

    /** Chart height as percentage of total height (95%). */
    const val CHART_HEIGHT_RATIO = 0.95

    /** Temperature range vertical padding (10% of range). */
    const val TEMP_RANGE_PADDING_RATIO = 0.10

    /** Opacity for daylight bars. */
    const val DAYLIGHT_BAR_OPACITY = 0.5

    /** Opacity for precipitation bars. */
    const val PRECIPITATION_BAR_OPACITY = 0.5
}

/**
 * Generates SVG meteogram charts natively in Kotlin.
 * This allows widget updates without starting a Flutter engine.
 */
class SvgChartGenerator {

    private var locale: Locale = Locale.getDefault()
    private var usesFahrenheit: Boolean = false
    private var use24HourFormat: Boolean = true

    /**
     * Generate SVG chart string.
     *
     * @param data Hourly weather data points
     * @param nowIndex Index of current hour in data array
     * @param latitude Geographic latitude for daylight calculation
     * @param longitude Geographic longitude for daylight calculation
     * @param colors Theme colors to use
     * @param width Chart width in pixels
     * @param height Chart height in pixels
     * @param locale Locale for time formatting
     * @param usesFahrenheit Whether to display temperature in Fahrenheit
     * @param use24HourFormat Whether to use 24-hour time format (false = 12-hour with AM/PM)
     * @param usePastFade Whether to fade past data
     * @return SVG string
     */
    fun generate(
        data: List<HourlyData>,
        nowIndex: Int,
        latitude: Double,
        longitude: Double,
        colors: SvgChartColors,
        width: Double,
        height: Double,
        locale: Locale = Locale.getDefault(),
        usesFahrenheit: Boolean = false,
        use24HourFormat: Boolean = true,
        usePastFade: Boolean = true
    ): String {
        this.locale = locale
        this.usesFahrenheit = usesFahrenheit
        this.use24HourFormat = use24HourFormat

        if (data.isEmpty()) {
            return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width.toInt()} ${height.toInt()}"></svg>"""
        }

        val svg = StringBuilder()

        // Reserve space for time labels based on font size
        val timeFontSize = width * ChartConstants.TIME_FONT_SIZE_RATIO
        val chartHeight = (height - timeFontSize * 1.5) * ChartConstants.CHART_HEIGHT_RATIO
        val nowFraction = (nowIndex + 1).toDouble() / data.size

        svg.append("""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width.toInt()} ${height.toInt()}">""")

        // Gradient definitions
        svg.append("<defs>")
        writeGradientDefs(svg, colors, nowFraction, usePastFade)
        svg.append("</defs>")

        // No background - widget uses system background via ?android:attr/colorBackground

        // Chart group with optional past-time fade mask
        if (usePastFade) {
            svg.append("""<g mask="url(#pastFadeMask)">""")
        } else {
            svg.append("<g>")
        }

        // Daylight bars (with gradient)
        writeDaylightBars(svg, data, latitude, longitude, colors, width, chartHeight)

        // Precipitation bars (with gradient)
        writePrecipitationBars(svg, data, colors, width, chartHeight)

        // Temperature line (with gradient fill)
        writeTemperatureLine(svg, data, colors, width, chartHeight)

        // Now indicator
        val nowX = (nowIndex.toDouble() / (data.size - 1)) * width
        svg.append("""<line x1="${nowX.toInt()}" y1="0" x2="${nowX.toInt()}" y2="${chartHeight.toInt()}" stroke="${colors.nowIndicator.toHex()}" stroke-width="3"/>""")

        // Grid lines at 12h intervals
        var i = nowIndex + 12
        while (i < data.size - 8) {
            val x = (i.toDouble() / (data.size - 1)) * width
            svg.append("""<line x1="${x.toInt()}" y1="0" x2="${x.toInt()}" y2="${chartHeight.toInt()}" stroke="${colors.timeLabel.toHex()}" stroke-width="1" opacity="0.3"/>""")
            i += 12
        }

        svg.append("</g>")

        // Temperature labels (outside mask for full opacity)
        writeTempLabels(svg, data, colors, width, chartHeight, nowFraction)

        // Time labels
        writeTimeLabels(svg, data, nowIndex, colors, width, height, chartHeight)

        svg.append("</svg>")
        return svg.toString()
    }

    /**
     * Write gradient definitions to SVG defs section.
     */
    private fun writeGradientDefs(
        svg: StringBuilder,
        colors: SvgChartColors,
        nowFraction: Double,
        usePastFade: Boolean
    ) {
        // Temperature area gradient (vertical: line color fading to transparent)
        svg.append("""<linearGradient id="tempGradient" x1="0" y1="0" x2="0" y2="1">""")
        svg.append("""<stop offset="0%" stop-color="${colors.temperatureLine.toHex()}" stop-opacity="${"%.2f".format(colors.temperatureGradientStart.opacity)}"/>""")
        svg.append("""<stop offset="100%" stop-color="${colors.temperatureLine.toHex()}" stop-opacity="${"%.2f".format(colors.temperatureGradientEnd.opacity)}"/>""")
        svg.append("</linearGradient>")

        // Daylight bar gradient (vertical: fades at top, semi-solid at bottom)
        svg.append("""<linearGradient id="daylightGradient" x1="0" y1="0" x2="0" y2="1">""")
        svg.append("""<stop offset="0%" stop-color="${colors.daylightBar.toHex()}" stop-opacity="0.7"/>""")
        svg.append("""<stop offset="100%" stop-color="${colors.daylightBar.toHex()}" stop-opacity="0.3"/>""")
        svg.append("</linearGradient>")

        // Precipitation bar gradient (vertical: fades at top, semi-solid at bottom)
        svg.append("""<linearGradient id="precipGradient" x1="0" y1="0" x2="0" y2="1">""")
        svg.append("""<stop offset="0%" stop-color="${colors.precipitationBar.toHex()}" stop-opacity="0.3"/>""")
        svg.append("""<stop offset="100%" stop-color="${colors.precipitationBar.toHex()}" stop-opacity="0.7"/>""")
        svg.append("</linearGradient>")

        // Past-time fade mask (horizontal gradient: faded on left, full opacity at now line)
        if (usePastFade) {
            val fadeStop1 = (nowFraction * 0.75 * 100).toInt()
            val fadeStop2 = (nowFraction * 100).toInt()
            svg.append("""<linearGradient id="pastFadeGradient" x1="0" y1="0" x2="1" y2="0">""")
            svg.append("""<stop offset="0%" stop-color="white" stop-opacity="0.15"/>""")
            svg.append("""<stop offset="$fadeStop1%" stop-color="white" stop-opacity="0.35"/>""")
            svg.append("""<stop offset="$fadeStop2%" stop-color="white" stop-opacity="1"/>""")
            svg.append("""<stop offset="100%" stop-color="white" stop-opacity="1"/>""")
            svg.append("</linearGradient>")
            svg.append("""<mask id="pastFadeMask"><rect width="100%" height="100%" fill="url(#pastFadeGradient)"/></mask>""")
        }
    }

    /**
     * Write daylight bars to SVG.
     */
    private fun writeDaylightBars(
        svg: StringBuilder,
        data: List<HourlyData>,
        latitude: Double,
        longitude: Double,
        colors: SvgChartColors,
        width: Double,
        chartHeight: Double
    ) {
        val slotWidth = width / data.size
        val barWidth = slotWidth * ChartConstants.BAR_WIDTH_RATIO

        val shadowOffset = 3

        // Draw shadows first (outside opacity group for visibility)
        svg.append("""<g opacity="0.4">""")
        for (i in data.indices) {
            val daylight = calculateDaylight(data[i], latitude, longitude)
            if (daylight <= 0) continue

            val barHeight = daylight * chartHeight
            val x = i * slotWidth + (slotWidth - barWidth) / 2

            svg.append("""<rect x="${(x + shadowOffset).toInt()}" y="$shadowOffset" width="${barWidth.toInt()}" height="${barHeight.toInt()}" fill="#000000" rx="2"/>""")
        }
        svg.append("</g>")

        // Draw main bars
        svg.append("""<g opacity="${ChartConstants.DAYLIGHT_BAR_OPACITY}">""")
        for (i in data.indices) {
            val daylight = calculateDaylight(data[i], latitude, longitude)
            if (daylight <= 0) continue

            val barHeight = daylight * chartHeight
            val x = i * slotWidth + (slotWidth - barWidth) / 2

            svg.append("""<rect x="${x.toInt()}" y="0" width="${barWidth.toInt()}" height="${barHeight.toInt()}" fill="url(#daylightGradient)" rx="2"/>""")
        }
        svg.append("</g>")
    }

    /**
     * Write precipitation bars to SVG.
     */
    private fun writePrecipitationBars(
        svg: StringBuilder,
        data: List<HourlyData>,
        colors: SvgChartColors,
        width: Double,
        chartHeight: Double
    ) {
        val maxPrecip = data.maxOfOrNull { it.precipitation } ?: 0.0
        if (maxPrecip == 0.0) return

        val slotWidth = width / data.size
        val barWidth = slotWidth * ChartConstants.BAR_WIDTH_RATIO

        val shadowOffset = 3

        // Draw shadows first (outside opacity group for visibility)
        svg.append("""<g opacity="0.4">""")
        for (i in data.indices) {
            val precip = data[i].precipitation
            if (precip <= 0) continue

            val normalized = (precip / 10.0).coerceIn(0.0, 1.0)
            val barHeight = sqrt(normalized) * chartHeight
            val x = i * slotWidth + (slotWidth - barWidth) / 2

            svg.append("""<rect x="${(x + shadowOffset).toInt()}" y="$shadowOffset" width="${barWidth.toInt()}" height="${barHeight.toInt()}" fill="#000000" rx="2"/>""")
        }
        svg.append("</g>")

        // Draw main bars
        svg.append("""<g opacity="${ChartConstants.PRECIPITATION_BAR_OPACITY}">""")
        for (i in data.indices) {
            val precip = data[i].precipitation
            if (precip <= 0) continue

            val normalized = (precip / 10.0).coerceIn(0.0, 1.0)
            val barHeight = sqrt(normalized) * chartHeight
            val x = i * slotWidth + (slotWidth - barWidth) / 2

            svg.append("""<rect x="${x.toInt()}" y="0" width="${barWidth.toInt()}" height="${barHeight.toInt()}" fill="url(#precipGradient)" rx="2"/>""")
        }
        svg.append("</g>")
    }

    /**
     * Write temperature line with gradient fill to SVG.
     */
    private fun writeTemperatureLine(
        svg: StringBuilder,
        data: List<HourlyData>,
        colors: SvgChartColors,
        width: Double,
        chartHeight: Double
    ) {
        val temps = data.map { it.temperature }
        val minTemp = temps.minOrNull() ?: 0.0
        val maxTemp = temps.maxOrNull() ?: 0.0
        val tempRange = (maxTemp - minTemp).coerceAtLeast(1.0)
        val yPadding = tempRange * ChartConstants.TEMP_RANGE_PADDING_RATIO

        val points = mutableListOf<Pair<Double, Double>>()
        for (i in data.indices) {
            val x = (i.toDouble() / (data.size - 1)) * width
            val normalizedTemp = (data[i].temperature - minTemp + yPadding) / (tempRange + 2 * yPadding)
            val y = chartHeight * (1 - normalizedTemp)
            points.add(Pair(x, y))
        }

        // Build smooth cubic bezier path
        val path = StringBuilder("M ${points[0].first.toInt()} ${points[0].second.toInt()}")
        for (i in 1 until points.size) {
            val p0 = points[i - 1]
            val p1 = points[i]
            val dx = p1.first - p0.first
            val cp1x = p0.first + dx * 0.35
            val cp2x = p1.first - dx * 0.35
            path.append(" C ${cp1x.toInt()} ${p0.second.toInt()} ${cp2x.toInt()} ${p1.second.toInt()} ${p1.first.toInt()} ${p1.second.toInt()}")
        }

        // Area fill with gradient
        val areaPath = "$path L ${width.toInt()} ${chartHeight.toInt()} L 0 ${chartHeight.toInt()} Z"
        svg.append("""<path d="$areaPath" fill="url(#tempGradient)" stroke="none"/>""")

        // Temperature line with offset drop shadow for depth
        val shadowOffset = 3
        svg.append("""<path d="$path" fill="none" stroke="#000000" stroke-width="4" stroke-opacity="0.5" stroke-linecap="round" stroke-linejoin="round" transform="translate($shadowOffset,$shadowOffset)"/>""")
        svg.append("""<path d="$path" fill="none" stroke="${colors.temperatureLine.toHex()}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>""")
    }

    /**
     * Format temperature for display, converting to Fahrenheit if needed.
     */
    private fun formatTemp(celsius: Double): String {
        return if (usesFahrenheit) {
            (celsius * 9 / 5 + 32).toInt().toString()
        } else {
            celsius.toInt().toString()
        }
    }

    /**
     * Write temperature labels to SVG.
     */
    private fun writeTempLabels(
        svg: StringBuilder,
        data: List<HourlyData>,
        colors: SvgChartColors,
        width: Double,
        chartHeight: Double,
        nowFraction: Double
    ) {
        val temps = data.map { it.temperature }
        val minTemp = temps.minOrNull() ?: 0.0
        val maxTemp = temps.maxOrNull() ?: 0.0
        val midTemp = (minTemp + maxTemp) / 2
        val tempRange = (maxTemp - minTemp).coerceAtLeast(1.0)
        val yPadding = tempRange * 0.10

        // Use same Y calculation as temperature line for alignment
        fun tempToY(temp: Double): Double {
            val normalizedTemp = (temp - minTemp + yPadding) / (tempRange + 2 * yPadding)
            return chartHeight * (1 - normalizedTemp)
        }

        val centerX = (nowFraction / 2.5) * width

        // Font size relative to width
        val fontSize = (width * ChartConstants.TEMP_FONT_SIZE_RATIO).toInt()
        val baseStyle = """font-size="$fontSize" font-weight="bold" font-family="sans-serif" text-anchor="middle" dominant-baseline="middle""""
        val shadowStyle = """fill="#000000" fill-opacity="0.6" $baseStyle"""
        val fillStyle = """fill="${colors.temperatureLine.toHex()}" $baseStyle"""

        // Align labels with actual temperature positions on the line
        // Add offset to account for text height
        val yOffset = fontSize * 0.4
        val shadowOffset = 4  // Shadow offset down and right

        // Draw each label: offset shadow first, then main text
        listOf(maxTemp, midTemp, minTemp).forEach { temp ->
            val y = (tempToY(temp) + yOffset).toInt()
            val text = formatTemp(temp)
            // Shadow (offset down-right)
            svg.append("""<text x="${centerX.toInt() + shadowOffset}" y="${y + shadowOffset}" $shadowStyle>$text</text>""")
            // Main text
            svg.append("""<text x="${centerX.toInt()}" y="$y" $fillStyle>$text</text>""")
        }
    }

    /**
     * Write time labels to SVG.
     */
    private fun writeTimeLabels(
        svg: StringBuilder,
        data: List<HourlyData>,
        nowIndex: Int,
        colors: SvgChartColors,
        width: Double,
        height: Double,
        chartHeight: Double
    ) {
        // Font size relative to width
        val fontSize = (width * ChartConstants.TIME_FONT_SIZE_RATIO).toInt()
        // Position labels 60% down in the area below the chart
        val labelY = chartHeight + (height - chartHeight) * 0.6
        val baseStyle = """font-size="$fontSize" font-weight="600" font-family="sans-serif" text-anchor="middle" dominant-baseline="middle""""
        val shadowStyle = """fill="#000000" fill-opacity="0.6" $baseStyle"""
        val fillStyle = """fill="${colors.timeLabel.toHex()}" $baseStyle"""
        val shadowOffset = 4  // Shadow offset down and right

        var i = nowIndex
        while (i < data.size - 8) {
            val offset = i - nowIndex
            if (offset >= 0 && offset % 12 == 0) {
                val date = Date(data[i].time)
                val timeStr = formatHourOnly(date)
                val x = (i.toDouble() / (data.size - 1)) * width

                // Shadow (offset down-right)
                svg.append("""<text x="${x.toInt() + shadowOffset}" y="${labelY.toInt() + shadowOffset}" $shadowStyle>$timeStr</text>""")
                // Main text
                svg.append("""<text x="${x.toInt()}" y="${labelY.toInt()}" $fillStyle>$timeStr</text>""")
            }
            i++
        }
    }

    /**
     * Format time to show only hour (locale-aware: "3 PM" or "15").
     */
    private fun formatHourOnly(date: Date): String {
        val calendar = Calendar.getInstance().apply {
            time = date
            timeZone = TimeZone.getDefault()
        }
        val hour = calendar.get(Calendar.HOUR_OF_DAY)

        return if (!use24HourFormat) {
            val hour12 = if (hour == 0) 12 else if (hour > 12) hour - 12 else hour
            val amPm = if (hour < 12) "AM" else "PM"
            "$hour12 $amPm"
        } else {
            hour.toString()
        }
    }

    // ==================== Scientific Calculations ====================

    /**
     * Calculate solar elevation angle using simplified solar position algorithm.
     *
     * This determines how high the sun is above the horizon at a given time and location.
     * Uses a simplified approximation suitable for daylight visualization.
     *
     * @param latitude Geographic latitude in degrees (-90 to +90)
     * @param longitude Geographic longitude in degrees (-180 to +180, positive = East)
     * @param timeMs UTC time in milliseconds
     * @return Solar elevation angle in degrees (negative = below horizon)
     */
    private fun solarElevation(latitude: Double, longitude: Double, timeMs: Long): Double {
        val calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            timeInMillis = timeMs
        }

        val dayOfYear = calendar.get(Calendar.DAY_OF_YEAR)
        val utcHour = calendar.get(Calendar.HOUR_OF_DAY) + calendar.get(Calendar.MINUTE) / 60.0

        // Solar declination: angle between sun's rays and equatorial plane
        val declination = 23.45 * sin(2 * Math.PI / 365 * (284 + dayOfYear))

        // Convert UTC to local solar time using longitude
        val solarHour = utcHour + longitude / 15.0

        // Hour angle: angular distance from solar noon
        val hourAngle = 15.0 * (solarHour - 12)

        // Convert to radians
        val latRad = Math.toRadians(latitude)
        val decRad = Math.toRadians(declination)
        val haRad = Math.toRadians(hourAngle)

        // Spherical trigonometry formula for solar elevation
        val sinElevation = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
        return Math.toDegrees(asin(sinElevation.coerceIn(-1.0, 1.0)))
    }

    /**
     * Calculate clear-sky illuminance at ground level in lux.
     *
     * Estimates how bright daylight would be with perfectly clear skies.
     *
     * @param elevation Solar elevation angle in degrees
     * @return Illuminance in lux (0 to ~133,000)
     */
    private fun clearSkyIlluminance(elevation: Double): Double {
        if (elevation < -6) return 0.0 // Below astronomical twilight

        val elevRad = Math.toRadians(elevation)
        val u = sin(elevRad)

        // Atmospheric mass approximation
        val x = 753.66156
        val s = asin((x * cos(elevRad) / (x + 1)).coerceIn(-1.0, 1.0))
        val m = x * (cos(s) - u) + cos(s)

        // Atmospheric extinction and scattering
        val factor = exp(-0.2 * m) * u + 0.0289 * exp(-0.042 * m) * (1 + (elevation + 90) * u / 57.29577951)

        return 133775 * factor.coerceAtLeast(0.0)
    }

    /**
     * Calculate effective daylight intensity (0.0 to 1.0) for display as bar height.
     *
     * Combines solar position, cloud cover, and precipitation.
     *
     * @param data Hourly weather data
     * @param latitude Geographic latitude
     * @param longitude Geographic longitude
     * @return Normalized daylight intensity (0.0 to 1.0)
     */
    private fun calculateDaylight(data: HourlyData, latitude: Double, longitude: Double): Double {
        val elevation = solarElevation(latitude, longitude, data.time)
        val clearSkyLux = clearSkyIlluminance(elevation)
        if (clearSkyLux <= 0) return 0.0

        // Normalize to 0-1 range
        val potential = (clearSkyLux / 130000.0).coerceIn(0.0, 1.0)

        // Attenuate by cloud cover (exponential)
        val cloudDivisor = 10.0.pow(data.cloudCover / 100.0)

        // Attenuate by precipitation
        val precipDivisor = 1 + 0.5 * data.precipitation.pow(0.6)

        // Apply sqrt for perceptual brightness
        return sqrt(potential / cloudDivisor / precipDivisor)
    }
}
