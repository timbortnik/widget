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
import kotlin.math.roundToInt
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
    val primaryText: SvgColor,
    val outlineColor: SvgColor = SvgColor(0x00, 0x00, 0x00),  // Stroke color for contrast
    val outlineOpacity: Double = 0.5,  // Stroke opacity
    val outlineWidth: Double = 2.0     // Stroke width
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
            temperatureLine = SvgColor(0xE0, 0x45, 0x45),  // Deeper red for light bg
            temperatureGradientStart = SvgColor(0xE0, 0x45, 0x45, 0x1A),  // 10% opacity
            temperatureGradientEnd = SvgColor(0xE0, 0x45, 0x45, 0x00),
            precipitationBar = SvgColor(0x1A, 0x9D, 0x92),  // Deeper teal for contrast on light bg
            daylightBar = SvgColor(0xFF, 0x8F, 0x00),      // Dark amber (visible on white)
            nowIndicator = SvgColor(0x4A, 0x55, 0x68),
            timeLabel = SvgColor(0x4A, 0x55, 0x68),
            cardBackground = SvgColor(0xFF, 0xFF, 0xFF),
            primaryText = SvgColor(0x2D, 0x34, 0x36),
            outlineColor = SvgColor(0xFF, 0xFF, 0xFF),      // Light outline for dark text
            outlineOpacity = 0.8,
            outlineWidth = 1.5
        )

        val dark = SvgChartColors(
            temperatureLine = SvgColor(0xFF, 0x5F, 0x5F),  // More saturated coral
            temperatureGradientStart = SvgColor(0xFF, 0x5F, 0x5F, 0x47),  // 28% opacity
            temperatureGradientEnd = SvgColor(0xFF, 0x5F, 0x5F, 0x00),
            precipitationBar = SvgColor(0x00, 0xCE, 0xC9),
            daylightBar = SvgColor(0xFF, 0xD5, 0x4F),        // Warm amber (matches icon)
            nowIndicator = SvgColor(0xFF, 0xFF, 0xFF),        // Pure white
            timeLabel = SvgColor(0xE0, 0xE0, 0xE0),
            cardBackground = SvgColor(0x2D, 0x2D, 0x2D),    // Neutral gray
            primaryText = SvgColor(0xFF, 0xFF, 0xFF),
            outlineColor = SvgColor(0x00, 0x00, 0x00),        // Dark outline for light text
            outlineOpacity = 0.6,
            outlineWidth = 1.5
        )
    }
}

/**
 * Format to use for time labels along the X axis.
 */
enum class TimeLabelFormat {
    /** Hour of day ("15" or "3 PM"). Used by the 48h meteogram. */
    HOUR,
    /** Short weekday abbreviation ("Sat"). Used by the weekly meteogram. */
    WEEKDAY
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

    /** Temperature range vertical padding (15% of range). */
    const val TEMP_RANGE_PADDING_RATIO = 0.15

    /** Opacity for daylight bars. */
    const val DAYLIGHT_BAR_OPACITY = 0.90

    /** Opacity for precipitation bars. */
    const val PRECIPITATION_BAR_OPACITY = 0.90
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
     * @param labelStepHours Spacing between X-axis labels and grid lines, in hours
     * @param labelFormat Format for X-axis labels (hour of day vs weekday)
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
        usePastFade: Boolean = true,
        labelStepHours: Int = 12,
        labelFormat: TimeLabelFormat = TimeLabelFormat.HOUR
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
        // Match the now-line's x position (nowIndex / (size-1)) so the
        // past-fade mask transitions exactly where the line sits, otherwise
        // the line can land in the mask's transition zone and appear
        // inconsistently bright across chart sizes.
        val nowFraction = if (data.size > 1) nowIndex.toDouble() / (data.size - 1) else 0.0

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
        svg.append("""<line x1="${nowX.toInt()}" y1="0" x2="${nowX.toInt()}" y2="${chartHeight.toInt()}" stroke="${colors.nowIndicator.toHex()}" stroke-width="4"/>""")

        // Grid lines. Weekday charts mark every local midnight so each day has
        // a clear left boundary; hour charts stick to fixed labelStepHours
        // intervals anchored on now.
        val step = labelStepHours.coerceAtLeast(1)
        if (labelFormat == TimeLabelFormat.WEEKDAY) {
            val gridCalendar = Calendar.getInstance(TimeZone.getDefault())
            for (i in data.indices) {
                if (i < 2 || i > data.size - 3) continue
                gridCalendar.time = Date(data[i].time)
                if (gridCalendar.get(Calendar.HOUR_OF_DAY) != 0) continue
                val x = (i.toDouble() / (data.size - 1)) * width
                svg.append("""<line x1="${x.toInt()}" y1="0" x2="${x.toInt()}" y2="${chartHeight.toInt()}" stroke="${colors.timeLabel.toHex()}" stroke-width="1" opacity="0.5"/>""")
            }
        } else {
            var i = nowIndex + step
            while (i < data.size - 4) {
                val x = (i.toDouble() / (data.size - 1)) * width
                svg.append("""<line x1="${x.toInt()}" y1="0" x2="${x.toInt()}" y2="${chartHeight.toInt()}" stroke="${colors.timeLabel.toHex()}" stroke-width="1" opacity="0.5"/>""")
                i += step
            }
        }

        svg.append("</g>")

        // Temperature labels (outside mask for full opacity)
        writeTempLabels(svg, data, colors, width, chartHeight, nowFraction)

        // Time labels
        writeTimeLabels(svg, data, nowIndex, colors, width, height, chartHeight, step, labelFormat)

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

        // Daylight bar gradient (vertical: solid where bars anchor at the top,
        // fading as they hang down — mirror of the precipitation bar range,
        // which is solid at the bottom where its bars anchor).
        svg.append("""<linearGradient id="daylightGradient" x1="0" y1="0" x2="0" y2="1">""")
        svg.append("""<stop offset="0%" stop-color="${colors.daylightBar.toHex()}" stop-opacity="0.9"/>""")
        svg.append("""<stop offset="100%" stop-color="${colors.daylightBar.toHex()}" stop-opacity="0.3"/>""")
        svg.append("</linearGradient>")

        // Precipitation bar gradient (vertical: solid at bottom, fades at top - bars grow upward)
        svg.append("""<linearGradient id="precipGradient" x1="0" y1="0" x2="0" y2="1">""")
        svg.append("""<stop offset="0%" stop-color="${colors.precipitationBar.toHex()}" stop-opacity="0.3"/>""")
        svg.append("""<stop offset="100%" stop-color="${colors.precipitationBar.toHex()}" stop-opacity="0.9"/>""")
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

        // Draw bars with contrasting outline
        svg.append("""<g opacity="${ChartConstants.DAYLIGHT_BAR_OPACITY}">""")
        for (i in data.indices) {
            val daylight = calculateDaylight(data[i], latitude, longitude)
            if (daylight <= 0) continue

            val barHeight = daylight * chartHeight
            val x = i * slotWidth + (slotWidth - barWidth) / 2

            svg.append("""<rect x="${x.toInt()}" y="0" width="${barWidth.toInt()}" height="${barHeight.toInt()}" fill="url(#daylightGradient)" stroke="${colors.outlineColor.toHex()}" stroke-width="1" stroke-opacity="${colors.outlineOpacity * 0.5}" rx="2"/>""")
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

        // Draw bars with contrasting outline (growing from bottom)
        svg.append("""<g opacity="${ChartConstants.PRECIPITATION_BAR_OPACITY}">""")
        for (i in data.indices) {
            val precip = data[i].precipitation
            if (precip <= 0) continue

            val normalized = (precip / 10.0).coerceIn(0.0, 1.0)
            val barHeight = sqrt(normalized) * chartHeight
            val x = i * slotWidth + (slotWidth - barWidth) / 2
            val y = chartHeight - barHeight  // Start from bottom

            svg.append("""<rect x="${x.toInt()}" y="${y.toInt()}" width="${barWidth.toInt()}" height="${barHeight.toInt()}" fill="url(#precipGradient)" stroke="${colors.outlineColor.toHex()}" stroke-width="1" stroke-opacity="${colors.outlineOpacity * 0.5}" rx="2"/>""")
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

        // Temperature line with contrasting outline
        svg.append("""<path d="$path" fill="none" stroke="${colors.outlineColor.toHex()}" stroke-width="5" stroke-opacity="${colors.outlineOpacity}" stroke-linecap="round" stroke-linejoin="round"/>""")
        svg.append("""<path d="$path" fill="none" stroke="${colors.temperatureLine.toHex()}" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/>""")
    }

    /**
     * Format temperature for display, converting to Fahrenheit if needed.
     */
    private fun formatTemp(celsius: Double): String {
        return if (usesFahrenheit) {
            (celsius * 9 / 5 + 32).roundToInt().toString()
        } else {
            celsius.roundToInt().toString()
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
        val yPadding = tempRange * ChartConstants.TEMP_RANGE_PADDING_RATIO

        // Use same Y calculation as temperature line for alignment
        fun tempToY(temp: Double): Double {
            val normalizedTemp = (temp - minTemp + yPadding) / (tempRange + 2 * yPadding)
            return chartHeight * (1 - normalizedTemp)
        }

        // Anchor labels inside the "past" region but keep them clear of the
        // left edge. The plain nowFraction/2.5 formula is near zero when the
        // past region is tiny (e.g. weekly mode with 6h past in 14 days),
        // which pushes the labels off the canvas — clamp to a sane minimum.
        val centerX = (nowFraction / 2.5).coerceAtLeast(0.05) * width

        // Font size relative to width
        val fontSize = (width * ChartConstants.TEMP_FONT_SIZE_RATIO).toInt()
        val baseStyle = """font-size="$fontSize" font-weight="bold" font-family="sans-serif" text-anchor="middle" dominant-baseline="middle""""
        val strokeStyle = """$baseStyle fill="none" stroke="${colors.outlineColor.toHex()}" stroke-width="${colors.outlineWidth}" stroke-opacity="${colors.outlineOpacity}""""
        val fillStyle = """$baseStyle fill="${colors.temperatureLine.toHex()}""""

        // Align labels with actual temperature positions on the line
        // Add offset to account for text height
        val yOffset = fontSize * 0.4

        // Draw each label: stroke first, then fill on top
        listOf(maxTemp, midTemp, minTemp).forEach { temp ->
            val y = (tempToY(temp) + yOffset).toInt()
            val text = formatTemp(temp)
            svg.append("""<text x="${centerX.toInt()}" y="$y" $strokeStyle>$text</text>""")
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
        chartHeight: Double,
        stepHours: Int,
        format: TimeLabelFormat
    ) {
        val step = stepHours.coerceAtLeast(1)
        // Font size relative to width
        val fontSize = (width * ChartConstants.TIME_FONT_SIZE_RATIO).toInt()
        // Position labels 60% down in the area below the chart
        val labelY = chartHeight + (height - chartHeight) * 0.6
        val baseStyle = """font-size="$fontSize" font-weight="600" font-family="sans-serif" text-anchor="middle" dominant-baseline="middle""""
        val strokeStyle = """$baseStyle fill="none" stroke="${colors.outlineColor.toHex()}" stroke-width="${colors.outlineWidth}" stroke-opacity="${colors.outlineOpacity}""""
        val fillStyle = """$baseStyle fill="${colors.timeLabel.toHex()}""""

        if (format == TimeLabelFormat.WEEKDAY) {
            // Weekday labels sit at local noon of each day so the label sits
            // in the middle of "its" day on the chart. The step controls how
            // many days apart labels are (e.g. 48h = every other day), and
            // the sequence is anchored on "today" so the first visible label
            // is today rather than whichever day the past window starts on.
            val dayStep = (step / 24).coerceAtLeast(1)
            val calendar = Calendar.getInstance(TimeZone.getDefault())
            calendar.time = Date(data[nowIndex.coerceIn(data.indices)].time)
            val todayOrdinal = calendar.get(Calendar.YEAR) * 400 + calendar.get(Calendar.DAY_OF_YEAR)
            for (i in data.indices) {
                if (i < 2 || i > data.size - 3) continue
                calendar.time = Date(data[i].time)
                if (calendar.get(Calendar.HOUR_OF_DAY) != 12) continue
                val delta = calendar.get(Calendar.YEAR) * 400 + calendar.get(Calendar.DAY_OF_YEAR) - todayOrdinal
                if (delta < 0 || delta % dayStep != 0) continue
                val timeStr = formatWeekday(Date(data[i].time))
                val x = (i.toDouble() / (data.size - 1)) * width
                svg.append("""<text x="${x.toInt()}" y="${labelY.toInt()}" $strokeStyle>$timeStr</text>""")
                svg.append("""<text x="${x.toInt()}" y="${labelY.toInt()}" $fillStyle>$timeStr</text>""")
            }
        } else {
            var i = nowIndex
            while (i < data.size - 4) {
                val offset = i - nowIndex
                if (offset >= 0 && offset % step == 0) {
                    val date = Date(data[i].time)
                    val timeStr = formatHourOnly(date)
                    val x = (i.toDouble() / (data.size - 1)) * width

                    svg.append("""<text x="${x.toInt()}" y="${labelY.toInt()}" $strokeStyle>$timeStr</text>""")
                    svg.append("""<text x="${x.toInt()}" y="${labelY.toInt()}" $fillStyle>$timeStr</text>""")
                }
                i++
            }
        }
    }

    /**
     * Format date using the CLDR "short" weekday width — the locale-defined
     * two-character form ("Mo", "Tu" in English; "Mo", "Di" in German;
     * "Пн", "Вт" in Russian). Uses android.icu which provides all four
     * CLDR widths (wide/abbreviated/short/narrow); java.text.SimpleDateFormat
     * only exposes wide, abbreviated, and narrow.
     */
    private fun formatWeekday(date: Date): String {
        val calendar = Calendar.getInstance().apply { time = date }
        val dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK)
        val symbols = android.icu.text.DateFormatSymbols.getInstance(locale)
        val shortNames = symbols.getWeekdays(
            android.icu.text.DateFormatSymbols.FORMAT,
            android.icu.text.DateFormatSymbols.SHORT
        )
        return shortNames[dayOfWeek]
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
