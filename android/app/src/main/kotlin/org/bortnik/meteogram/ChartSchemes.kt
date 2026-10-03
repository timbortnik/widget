package org.bortnik.meteogram

/**
 * Fixed chart palettes the user can pick instead of the Material You default.
 *
 * A scheme is orthogonal to light/dark: each one defines both variants, so
 * picking a scheme never overrides the user's theme choice.
 *
 * These palettes cover the meteogram. App chrome (surfaces, text, accents)
 * stays on Material You under [DEFAULT]; the fixed schemes are tuned for a
 * specific ground, so they paint it into the chart itself (reaching the
 * widget) and the in-app card follows suit — the Dart side mirrors the card
 * colours in `ChartScheme.cardColors`.
 * See [WidgetChartColors] for the single point where the choice is resolved.
 *
 * Bars are the only same-shape pair, and they grow from opposite edges
 * (daylight from the top, precipitation from the bottom). [CONTRAST] is the
 * accessibility scheme, so it separates them by a blue-vs-amber hue pair that
 * survives colour blindness. [ARCTIC] is a mood scheme where colour-vision
 * safety is explicitly not a goal; its bars are both cool, so they differ in
 * lightness (bright snow, dim sun) instead.
 */
object ChartSchemes {
    /** Material You on Android 12+, built-in presets below it. The default. */
    const val DEFAULT = "default"

    /** Polar day and dusk: low apricot sun, ice-blue cold, snow. */
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

    // Polar day and dusk, lit by a low apricot sun. Light is polar day:
    // periwinkle snow-light reflecting the sky, so the warm sun sits
    // near-complementary to its ground and the line's fill stays a cool
    // shadow (on rose it cancelled to grey). Dark is polar dusk: a plum sky,
    // sharing Light's violet lean so both read as one scheme, with the sun
    // and the ice-blue line nearly opposite on the wheel. Apricot, not
    // gold: gold read as mustard/ochre. The "now" marker matches the time
    // labels, so it reads as part of the time axis rather than as a series.
    // Precipitation splits by phase (from the forecast's own snowfall):
    // snow white, rain blue — a deeper cobalt/royal than the ice-blue line
    // it sits under near 0°C. In light the ground is too pale for white
    // snow, so snow turns slate ("snow in shadow").
    val arcticLight = SvgChartColors(
        temperatureLine = SvgColor(0x1A, 0x66, 0x84),      // Steel-teal: opposite the apricot sun
        temperatureGradientStart = SvgColor(0x1A, 0x66, 0x84, 0x1A),  // 10% opacity
        temperatureGradientEnd = SvgColor(0x1A, 0x66, 0x84, 0x00),
        precipitationBar = SvgColor(0x2F, 0x5F, 0xC0),          // Rain
        daylightBar = SvgColor(0xD9, 0x86, 0x4F),
        nowIndicator = SvgColor(0x3B, 0x42, 0x52),      // Same as the time labels
        timeLabel = SvgColor(0x3B, 0x42, 0x52),
        cardBackground = SvgColor(0xE7, 0xE9, 0xF4),
        primaryText = SvgColor(0x2E, 0x34, 0x40),
        outlineColor = SvgColor(0xE7, 0xE9, 0xF4),      // Halo matches the ground
        outlineOpacity = 0.8,
        outlineWidth = 1.5,
        // Temperature colour-coded on an absolute °C scale, stops every 20°
        // so equal changes shift the colour equally: indigo deep cold (polar
        // night), steel-teal at freezing, slate mild (20°C), rose-red hot
        // (40°C).
        // Rose, not orange, so hot afternoon peaks don't melt into the
        // apricot sun bars they cross. Clamped beyond both ends.
        snowBar = SvgColor(0x35, 0x40, 0x50),
        temperatureScale = listOf(
            -20.0 to SvgColor(0x3B, 0x3A, 0x8F),
            0.0 to SvgColor(0x1A, 0x66, 0x84),
            20.0 to SvgColor(0x52, 0x58, 0x6A),
            40.0 to SvgColor(0xB8, 0x3A, 0x50)
        ),
        // Bars keep the default gradient: Arctic is a mood scheme, and the
        // fade is part of the chart's look.
        drawBackground = true
    )

    val arcticDark = SvgChartColors(
        temperatureLine = SvgColor(0x8F, 0xC9, 0xE0),
        temperatureGradientStart = SvgColor(0x8F, 0xC9, 0xE0, 0x47),  // 28% opacity
        temperatureGradientEnd = SvgColor(0x8F, 0xC9, 0xE0, 0x00),
        precipitationBar = SvgColor(0x5B, 0x8D, 0xEF),          // Rain
        daylightBar = SvgColor(0xE0, 0x90, 0x60),          // Dimmed to sit below the line
        nowIndicator = SvgColor(0xD8, 0xDE, 0xE9),      // Same as the time labels
        timeLabel = SvgColor(0xD8, 0xDE, 0xE9),
        cardBackground = SvgColor(0x2A, 0x1D, 0x2E),
        primaryText = SvgColor(0xEC, 0xEF, 0xF4),
        outlineColor = SvgColor(0x2A, 0x1D, 0x2E),      // Halo matches the ground
        outlineOpacity = 0.6,
        outlineWidth = 1.5,
        snowBar = SvgColor(0xEE, 0xF3, 0xF7),
        // Dark mirrors Light's hues; the deep-cold violet goes light
        // (lavender) because a deep indigo would vanish on plum.
        temperatureScale = listOf(
            -20.0 to SvgColor(0xB8, 0xA8, 0xF0),
            0.0 to SvgColor(0x8F, 0xC9, 0xE0),
            20.0 to SvgColor(0xD8, 0xD4, 0xDC),
            40.0 to SvgColor(0xF2, 0x70, 0x8A)
        ),
        drawBackground = true
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
