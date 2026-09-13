package org.bortnik.meteogram

/**
 * Fixed chart palettes the user can pick instead of the Material You default.
 *
 * A scheme is orthogonal to light/dark: each one defines both variants, so
 * picking a scheme never overrides the user's theme choice.
 *
 * These palettes cover the meteogram only. App chrome (surfaces, text,
 * accents) stays on Material You in every scheme — see [WidgetChartColors] for
 * the single point where the choice is resolved.
 *
 * Colour-vision safety: the two bar series are the only same-shape pair, so
 * precipitation stays blue and daylight stays amber in every scheme. The
 * temperature series is a line, so its red never has to be told apart from a
 * bar by hue alone.
 */
object ChartSchemes {
    /** Material You on Android 12+, built-in presets below it. The default. */
    const val DEFAULT = "default"

    /** Cool, muted arctic palette. */
    const val ARCTIC = "arctic"

    /** Maximum-contrast palette: pure black/white grounds, widened strokes. */
    const val CONTRAST = "contrast"

    /** All valid scheme ids, in the order the picker lists them. */
    val ids = listOf(DEFAULT, ARCTIC, CONTRAST)

    /**
     * Resolve a stored scheme id to a fixed palette, or null when the id is
     * [DEFAULT], unknown, or absent — in which case the caller keeps the
     * existing Material You path.
     */
    // Block body rather than `= when (...)` on purpose: Codacy's Lizard cannot
    // parse Kotlin expression bodies and keeps consuming to the end of the
    // enclosing object, reporting this 5-line dispatch as a 66-line function.
    fun palette(id: String?, isLight: Boolean): SvgChartColors? {
        return when (id) {
            ARCTIC -> if (isLight) arcticLight else arcticDark
            CONTRAST -> if (isLight) contrastLight else contrastDark
            else -> null
        }
    }

    val arcticLight = SvgChartColors(
        temperatureLine = SvgColor(0xB0, 0x42, 0x4D),
        temperatureGradientStart = SvgColor(0xB0, 0x42, 0x4D, 0x1A),  // 10% opacity
        temperatureGradientEnd = SvgColor(0xB0, 0x42, 0x4D, 0x00),
        precipitationBar = SvgColor(0x4C, 0x6E, 0x9C),
        daylightBar = SvgColor(0xB0, 0x7D, 0x2B),
        nowIndicator = SvgColor(0x43, 0x4C, 0x5E),
        timeLabel = SvgColor(0x3B, 0x42, 0x52),
        cardBackground = SvgColor(0xEC, 0xEF, 0xF4),
        primaryText = SvgColor(0x2E, 0x34, 0x40),
        outlineColor = SvgColor(0xEC, 0xEF, 0xF4),      // Light outline for dark text
        outlineOpacity = 0.8,
        outlineWidth = 1.5
    )

    val arcticDark = SvgChartColors(
        temperatureLine = SvgColor(0xD0, 0x80, 0x88),
        temperatureGradientStart = SvgColor(0xD0, 0x80, 0x88, 0x47),  // 28% opacity
        temperatureGradientEnd = SvgColor(0xD0, 0x80, 0x88, 0x00),
        precipitationBar = SvgColor(0x88, 0xC0, 0xD0),
        daylightBar = SvgColor(0xEB, 0xCB, 0x8B),
        nowIndicator = SvgColor(0xEC, 0xEF, 0xF4),
        timeLabel = SvgColor(0xD8, 0xDE, 0xE9),
        cardBackground = SvgColor(0x2E, 0x34, 0x40),
        primaryText = SvgColor(0xEC, 0xEF, 0xF4),
        outlineColor = SvgColor(0x2E, 0x34, 0x40),      // Dark outline for light text
        outlineOpacity = 0.6,
        outlineWidth = 1.5
    )

    val contrastLight = SvgChartColors(
        temperatureLine = SvgColor(0xC0, 0x00, 0x00),
        temperatureGradientStart = SvgColor(0xC0, 0x00, 0x00, 0x1A),
        temperatureGradientEnd = SvgColor(0xC0, 0x00, 0x00, 0x00),
        precipitationBar = SvgColor(0x0B, 0x4F, 0xA8),
        daylightBar = SvgColor(0x8A, 0x4B, 0x00),
        nowIndicator = SvgColor(0x00, 0x00, 0x00),
        timeLabel = SvgColor(0x00, 0x00, 0x00),
        cardBackground = SvgColor(0xFF, 0xFF, 0xFF),
        primaryText = SvgColor(0x00, 0x00, 0x00),
        outlineColor = SvgColor(0xFF, 0xFF, 0xFF),
        outlineOpacity = 1.0,
        outlineWidth = 2.0,
        temperatureLineWidth = 4.5,
        nowIndicatorWidth = 5.0
    )

    val contrastDark = SvgChartColors(
        temperatureLine = SvgColor(0xFF, 0x5A, 0x5A),
        temperatureGradientStart = SvgColor(0xFF, 0x5A, 0x5A, 0x47),
        temperatureGradientEnd = SvgColor(0xFF, 0x5A, 0x5A, 0x00),
        precipitationBar = SvgColor(0x4F, 0xC3, 0xF7),
        daylightBar = SvgColor(0xFF, 0xD5, 0x4F),
        nowIndicator = SvgColor(0xFF, 0xFF, 0xFF),
        timeLabel = SvgColor(0xFF, 0xFF, 0xFF),
        cardBackground = SvgColor(0x00, 0x00, 0x00),
        primaryText = SvgColor(0xFF, 0xFF, 0xFF),
        outlineColor = SvgColor(0x00, 0x00, 0x00),
        outlineOpacity = 1.0,
        outlineWidth = 2.0,
        temperatureLineWidth = 4.5,
        nowIndicatorWidth = 5.0
    )
}
