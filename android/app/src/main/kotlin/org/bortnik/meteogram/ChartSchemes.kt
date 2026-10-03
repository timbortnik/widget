package org.bortnik.meteogram

/**
 * Fixed chart palettes the user can pick instead of the Material You default.
 *
 * A scheme is orthogonal to light/dark: each one defines both variants, so
 * picking a scheme never overrides the user's theme choice.
 *
 * These palettes cover the meteogram. App chrome (surfaces, text, accents)
 * stays on Material You in every scheme, except [CONTRAST]: its palette is
 * tuned for pure white/black, so it paints that ground into the chart itself
 * (reaching the widget) and the in-app card follows suit — the Dart side
 * mirrors `cardBackground` in `ChartScheme.cardBackground`.
 * See [WidgetChartColors] for the single point where the choice is resolved.
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

    // Temperature is drawn in ink (black/white) rather than a hue: it is the
    // primary series, so it takes the strongest contrast, and an achromatic
    // line can't be confused with either bar under any colour-vision
    // deficiency. The "now" marker takes the accent colour instead, so the
    // two never meet at the same colour where they cross. The accent keeps one
    // crimson hue across both variants and sits in the hue gap between the
    // amber and blue bars, so it never reads as part of either series.
    val contrastLight = SvgChartColors(
        temperatureLine = SvgColor(0x00, 0x00, 0x00),
        temperatureGradientStart = SvgColor(0x00, 0x00, 0x00, 0x1A),
        temperatureGradientEnd = SvgColor(0x00, 0x00, 0x00, 0x00),
        precipitationBar = SvgColor(0x0B, 0x4F, 0xA8),
        daylightBar = SvgColor(0xC8, 0x70, 0x00),          // Light enough to read as sun, not brown
        nowIndicator = SvgColor(0xB0, 0x00, 0x5A),
        timeLabel = SvgColor(0x00, 0x00, 0x00),
        cardBackground = SvgColor(0xFF, 0xFF, 0xFF),
        primaryText = SvgColor(0x00, 0x00, 0x00),
        outlineColor = SvgColor(0xFF, 0xFF, 0xFF),
        outlineOpacity = 1.0,
        outlineWidth = 2.0,
        temperatureLineWidth = 4.5,
        nowIndicatorWidth = 5.0,
        // Solid bars: amber only stops reading as brown once it is light,
        // and a light amber can't afford any fade and still hold 3:1.
        barGradientSolid = 1.0,
        barGradientFaint = 1.0,
        drawBackground = true
    )

    val contrastDark = SvgChartColors(
        temperatureLine = SvgColor(0xFF, 0xFF, 0xFF),
        temperatureGradientStart = SvgColor(0xFF, 0xFF, 0xFF, 0x47),
        temperatureGradientEnd = SvgColor(0xFF, 0xFF, 0xFF, 0x00),
        precipitationBar = SvgColor(0x4F, 0xC3, 0xF7),
        daylightBar = SvgColor(0xE6, 0xB8, 0x4A),
        nowIndicator = SvgColor(0xFF, 0x5C, 0x9A),      // Light's crimson hue, lifted for black
        timeLabel = SvgColor(0xFF, 0xFF, 0xFF),
        cardBackground = SvgColor(0x00, 0x00, 0x00),
        primaryText = SvgColor(0xFF, 0xFF, 0xFF),
        outlineColor = SvgColor(0x00, 0x00, 0x00),
        outlineOpacity = 1.0,
        outlineWidth = 2.0,
        temperatureLineWidth = 4.5,
        nowIndicatorWidth = 5.0,
        // Solid bars: amber only stops reading as brown once it is light,
        // and a light amber can't afford any fade and still hold 3:1.
        barGradientSolid = 1.0,
        barGradientFaint = 1.0,
        drawBackground = true
    )
}
