package org.bortnik.meteogram

import java.util.Locale
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for SvgChartGenerator and related classes.
 * Weekday formatting uses android.icu at runtime; that path is exercised on
 * device rather than here because Robolectric does not shadow android.icu.
 */
class SvgChartGeneratorTest {

    // ==================== SvgColor Tests ====================

    @Test
    fun `SvgColor toHex returns correct hex string`() {
        val color = SvgColor(0xFF, 0x6B, 0x6B)
        assertEquals("#ff6b6b", color.toHex())
    }

    @Test
    fun `SvgColor toHex handles zeros`() {
        val color = SvgColor(0x00, 0x00, 0x00)
        assertEquals("#000000", color.toHex())
    }

    @Test
    fun `SvgColor toHex handles white`() {
        val color = SvgColor(0xFF, 0xFF, 0xFF)
        assertEquals("#ffffff", color.toHex())
    }

    @Test
    fun `SvgColor opacity returns correct value`() {
        val fullyOpaque = SvgColor(0, 0, 0, 255)
        assertEquals(1.0, fullyOpaque.opacity, 0.001)

        val halfTransparent = SvgColor(0, 0, 0, 128)
        assertEquals(0.502, halfTransparent.opacity, 0.01)

        val fullyTransparent = SvgColor(0, 0, 0, 0)
        assertEquals(0.0, fullyTransparent.opacity, 0.001)
    }

    @Test
    fun `SvgColor fromArgb parses ARGB int correctly`() {
        // ARGB: 0xFFRRGGBB (fully opaque red)
        val argb = 0xFFFF0000.toInt()
        val color = SvgColor.fromArgb(argb)

        assertEquals(255, color.r)
        assertEquals(0, color.g)
        assertEquals(0, color.b)
        assertEquals(255, color.a)
    }

    @Test
    fun `SvgColor fromArgb handles transparency`() {
        // ARGB: 0x80RRGGBB (50% transparent green)
        val argb = 0x8000FF00.toInt()
        val color = SvgColor.fromArgb(argb)

        assertEquals(0, color.r)
        assertEquals(255, color.g)
        assertEquals(0, color.b)
        assertEquals(128, color.a)
    }

    // ==================== SvgChartColors Tests ====================

    @Test
    fun `SvgChartColors light preset has expected values`() {
        val light = SvgChartColors.light

        assertEquals("#e04545", light.temperatureLine.toHex())  // Deeper red for light bg
        assertEquals("#1a9d92", light.precipitationBar.toHex())  // Deeper teal for contrast on light bg
    }

    @Test
    fun `SvgChartColors dark preset has expected values`() {
        val dark = SvgChartColors.dark

        assertEquals("#ff5f5f", dark.temperatureLine.toHex())  // More saturated coral
        assertEquals("#00cec9", dark.precipitationBar.toHex())
    }

    @Test
    fun `SvgChartColors default stroke widths preserve the original chart`() {
        // These were literals in the SVG before schemes existed; the defaults
        // must keep reproducing the same output for the Material You path.
        val light = SvgChartColors.light

        assertEquals(3.5, light.temperatureLineWidth, 0.0)
        assertEquals(5.0, light.temperatureOutlineWidth, 0.0)
        assertEquals(4.0, light.nowIndicatorWidth, 0.0)
    }

    @Test
    fun `SvgChartColors temperature outline stays wider than the line`() {
        val contrast = ChartSchemes.contrastLight

        assertEquals(4.5, contrast.temperatureLineWidth, 0.0)
        assertEquals(6.0, contrast.temperatureOutlineWidth, 0.0)
    }

    // ==================== ChartSchemes Tests ====================

    @Test
    fun `ChartSchemes palette returns null for the default scheme`() {
        // Null keeps the caller on the existing Material You path.
        assertNull(ChartSchemes.palette(ChartSchemes.DEFAULT, isLight = true))
        assertNull(ChartSchemes.palette(ChartSchemes.DEFAULT, isLight = false))
    }

    @Test
    fun `ChartSchemes palette returns null for unknown or absent ids`() {
        assertNull(ChartSchemes.palette(null, isLight = true))
        assertNull(ChartSchemes.palette("", isLight = true))
        assertNull(ChartSchemes.palette("scheme-from-a-newer-version", isLight = true))
    }

    @Test
    fun `ChartSchemes palette resolves each fixed scheme per theme`() {
        assertEquals(ChartSchemes.thermalLight, ChartSchemes.palette(ChartSchemes.THERMAL, isLight = true))
        assertEquals(ChartSchemes.thermalDark, ChartSchemes.palette(ChartSchemes.THERMAL, isLight = false))
        assertEquals(ChartSchemes.contrastLight, ChartSchemes.palette(ChartSchemes.CONTRAST, isLight = true))
        assertEquals(ChartSchemes.contrastDark, ChartSchemes.palette(ChartSchemes.CONTRAST, isLight = false))
    }

    @Test
    fun `ChartSchemes ids lists every scheme the picker offers`() {
        assertEquals(listOf("default", "thermal", "contrast"), ChartSchemes.ids)
        // Every non-default id must resolve, or the picker offers a dead option.
        for (id in ChartSchemes.ids - ChartSchemes.DEFAULT) {
            assertNotNull("scheme '$id' has no light palette", ChartSchemes.palette(id, isLight = true))
            assertNotNull("scheme '$id' has no dark palette", ChartSchemes.palette(id, isLight = false))
        }
    }

    @Test
    fun `ChartSchemes light and dark variants differ per scheme`() {
        // A scheme that ignored the theme would render white-on-white for half
        // the users; the two variants must be genuinely distinct.
        assertNotEquals(ChartSchemes.thermalLight, ChartSchemes.thermalDark)
        assertNotEquals(ChartSchemes.contrastLight, ChartSchemes.contrastDark)
    }

    @Test
    fun `ChartSchemes contrast bars stay blue-vs-amber for colour-vision safety`() {
        // Precipitation and daylight are the only same-shape series; high
        // contrast separates them by a hue pair that survives protan/deutan.
        for (palette in listOf(ChartSchemes.contrastLight, ChartSchemes.contrastDark)) {
            val rain = palette.precipitationBar
            val sun = palette.daylightBar
            assertTrue("precipitation should read as blue: ${rain.toHex()}", rain.b > rain.r)
            assertTrue("daylight should read as amber: ${sun.toHex()}", sun.r > sun.b)
        }
    }

    @Test
    fun `ChartSchemes thermal snow and rain bars are clearly distinct`() {
        // Thermal colours precipitation by phase, so the two must never be
        // mistaken for one another.
        fun distance(a: SvgColor, b: SvgColor) =
            Math.sqrt(((a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b)).toDouble())

        for (palette in listOf(ChartSchemes.thermalLight, ChartSchemes.thermalDark)) {
            val snow = palette.snowBar!!
            val rain = palette.precipitationBar
            assertTrue("snow ${snow.toHex()} too close to rain ${rain.toHex()}", distance(snow, rain) > 80.0)
        }
    }

    @Test
    fun `HourlyData isSnow follows the dominant phase by water equivalent`() {
        fun hour(precip: Double, snowCm: Double) = HourlyData(0L, -1.0, precip, 100, snowCm)

        assertFalse("no precipitation", hour(0.0, 0.0).isSnow)
        assertFalse("all rain", hour(2.0, 0.0).isSnow)
        assertTrue("all snow: 1.4 cm = 2 mm", hour(2.0, 1.4).isSnow)
        assertTrue("half snow counts as snow", hour(2.0, 0.7).isSnow)
        assertFalse("mostly rain", hour(2.0, 0.3).isSnow)
    }

    @Test
    fun `generate colours precipitation by phase only for palettes with a snow colour`() {
        val now = System.currentTimeMillis()
        val data = (0 until 24).map {
            // Even hours snow, odd hours rain.
            HourlyData(now + it * 3_600_000L, -1.0, 2.0, 100, if (it % 2 == 0) 1.4 else 0.0)
        }
        fun svgFor(colors: SvgChartColors) = SvgChartGenerator().generate(
            data = data, nowIndex = 6, latitude = 52.52, longitude = 13.405,
            colors = colors, width = 800.0, height = 400.0
        )

        val thermal = svgFor(ChartSchemes.thermalDark)
        assertTrue(thermal.contains("""<linearGradient id="snowGradient""""))
        assertEquals(12, Regex("""fill="url\(#snowGradient\)"""").findAll(thermal).count())
        assertEquals(12, Regex("""fill="url\(#precipGradient\)"""").findAll(thermal).count())

        val plain = svgFor(SvgChartColors.dark)
        assertFalse(plain.contains("snowGradient"))
        assertEquals(24, Regex("""fill="url\(#precipGradient\)"""").findAll(plain).count())
    }

    @Test
    fun `ChartSchemes text contrasts its own background`() {
        // Labels are drawn over the card, so a scheme whose text and ground sit
        // at the same luminance is unreadable regardless of hue.
        fun luminance(c: SvgColor) = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

        for (palette in listOf(
            ChartSchemes.thermalLight, ChartSchemes.thermalDark,
            ChartSchemes.contrastLight, ChartSchemes.contrastDark
        )) {
            val spread = Math.abs(luminance(palette.primaryText) - luminance(palette.cardBackground))
            assertTrue("text/background too close (spread=$spread)", spread > 100.0)
            // The outline is the halo behind text, so it must side with the
            // background rather than the text it is meant to separate.
            val outlineToBg = Math.abs(luminance(palette.outlineColor) - luminance(palette.cardBackground))
            assertTrue("outline should match the ground (delta=$outlineToBg)", outlineToBg < 40.0)
        }
    }

    @Test
    fun `ChartSchemes contrast colours match the Dart card mirror`() {
        // ChartScheme.cardColors (scheme_service.dart) repeats these so the
        // in-app card header matches the chart; pinned there too.
        val light = ChartSchemes.contrastLight
        assertEquals("#ffffff", light.cardBackground.toHex())
        assertEquals("#000000", light.temperatureLine.toHex())
        assertEquals("#c87000", light.daylightBar.toHex())
        assertEquals("#0b4fa8", light.precipitationBar.toHex())

        val dark = ChartSchemes.contrastDark
        assertEquals("#000000", dark.cardBackground.toHex())
        assertEquals("#ffffff", dark.temperatureLine.toHex())
        assertEquals("#e6b84a", dark.daylightBar.toHex())
        assertEquals("#4fc3f7", dark.precipitationBar.toHex())
    }

    @Test
    fun `ChartSchemes thermal colours match the Dart card mirror`() {
        // ChartScheme.cardColors (scheme_service.dart) repeats these; pinned there too.
        val light = ChartSchemes.thermalLight
        assertEquals("#e7e9f4", light.cardBackground.toHex())
        assertEquals("#1a6684", light.temperatureLine.toHex())
        assertEquals("#2e3440", light.primaryText.toHex())
        assertEquals("#d9864f", light.daylightBar.toHex())
        assertEquals("#2f5fc0", light.precipitationBar.toHex())
        assertEquals("#7a8aa0", light.snowBar?.toHex())

        val dark = ChartSchemes.thermalDark
        assertEquals("#2a1d2e", dark.cardBackground.toHex())
        assertEquals("#8fc9e0", dark.temperatureLine.toHex())
        assertEquals("#eceff4", dark.primaryText.toHex())
        assertEquals("#e09060", dark.daylightBar.toHex())
        assertEquals("#5b8def", dark.precipitationBar.toHex())
        assertEquals("#eef3f7", dark.snowBar?.toHex())
    }

    @Test
    fun `generate honours scheme stroke widths`() {
        val data = createTestData(24)

        val svg = SvgChartGenerator().generate(
            data = data,
            nowIndex = 6,
            latitude = 52.52,
            longitude = 13.405,
            colors = ChartSchemes.contrastDark,
            width = 800.0,
            height = 400.0
        )

        assertTrue("temperature line should use the scheme width", svg.contains("stroke-width=\"4.5\""))
        assertTrue("now marker should use the scheme width", svg.contains("stroke-width=\"5.0\""))
        assertTrue(svg.contains(ChartSchemes.contrastDark.temperatureLine.toHex()))
    }

    @Test
    fun `generate keeps the original bar gradient for the default palette`() {
        // These were literals before schemes could set them; the default path
        // must keep emitting exactly the same stops.
        val svg = SvgChartGenerator().generate(
            data = createTestData(24),
            nowIndex = 6,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.light,
            width = 800.0,
            height = 400.0
        )

        assertTrue(svg.contains("stop-opacity=\"0.9\""))
        assertTrue(svg.contains("stop-opacity=\"0.3\""))
    }

    @Test
    fun `generate honours scheme bar gradient`() {
        val svg = SvgChartGenerator().generate(
            data = createTestData(24),
            nowIndex = 6,
            latitude = 52.52,
            longitude = 13.405,
            colors = ChartSchemes.contrastLight,
            width = 800.0,
            height = 400.0
        )

        assertTrue("bars should use the scheme opacity", svg.contains("stop-opacity=\"1.0\""))
        assertFalse("default faint end must not leak through", svg.contains("stop-opacity=\"0.3\""))
    }

    @Test
    fun `generate leaves the default chart transparent`() {
        // The widget shows the system background and the app its Material You
        // card through the chart; a painted ground would cover both.
        val svg = SvgChartGenerator().generate(
            data = createTestData(24),
            nowIndex = 6,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.light,
            width = 800.0,
            height = 400.0
        )

        assertFalse(svg.contains("<rect x=\"0\" y=\"0\" width=\"800\" height=\"400\""))
    }

    @Test
    fun `generate paints the ground for schemes that own it`() {
        for (palette in listOf(
            ChartSchemes.thermalLight, ChartSchemes.thermalDark,
            ChartSchemes.contrastLight, ChartSchemes.contrastDark
        )) {
            val data = createTestData(24)
            val svg = SvgChartGenerator().generate(
                data = data,
                nowIndex = 6,
                latitude = 52.52,
                longitude = 13.405,
                colors = palette,
                width = 800.0,
                height = 400.0,
                usePastFade = true
            )
            // A ground scale moves the ground with the current hour.
            val fill = palette.atTemperature(data[6].temperature).cardBackground.toHex()
            val ground = "<rect x=\"0\" y=\"0\" width=\"800\" height=\"400\" fill=\"$fill\"/>"

            assertTrue("ground should be painted", svg.contains(ground))
            // Outside the past-fade mask, or the past region would fade to transparent.
            assertTrue("ground must precede the masked group",
                svg.indexOf(ground) < svg.indexOf("mask=\"url(#pastFadeMask)\""))
        }
    }

    @Test
    fun `SvgChartColors withDynamicColors updates temperature and time label`() {
        val original = SvgChartColors.light
        val newTempColor = SvgColor(0x12, 0x34, 0x56)
        val newTimeColor = SvgColor(0xAB, 0xCD, 0xEF)

        val updated = original.withDynamicColors(newTempColor, newTimeColor)

        assertEquals(newTempColor, updated.temperatureLine)
        assertEquals(newTimeColor, updated.timeLabel)
        // Gradient start should use new color with original alpha
        assertEquals(0x12, updated.temperatureGradientStart.r)
        assertEquals(0x34, updated.temperatureGradientStart.g)
        assertEquals(0x56, updated.temperatureGradientStart.b)
        // Gradient end should be fully transparent
        assertEquals(0, updated.temperatureGradientEnd.a)
        // Other colors should remain unchanged
        assertEquals(original.precipitationBar, updated.precipitationBar)
    }

    // ==================== ChartConstants Tests ====================

    @Test
    fun `ChartConstants has valid ratios`() {
        assertTrue(ChartConstants.TIME_FONT_SIZE_RATIO > 0)
        assertTrue(ChartConstants.TIME_FONT_SIZE_RATIO < 1)
        assertTrue(ChartConstants.CHART_HEIGHT_RATIO > 0)
        assertTrue(ChartConstants.CHART_HEIGHT_RATIO <= 1)
        assertTrue(ChartConstants.BAR_WIDTH_RATIO > 0)
        assertTrue(ChartConstants.BAR_WIDTH_RATIO <= 1)
    }

    // ==================== HourlyData Tests ====================

    @Test
    fun `HourlyData stores values correctly`() {
        val data = HourlyData(
            time = 1705500000000L,
            temperature = 15.5,
            precipitation = 2.3,
            cloudCover = 75
        )

        assertEquals(1705500000000L, data.time)
        assertEquals(15.5, data.temperature, 0.001)
        assertEquals(2.3, data.precipitation, 0.001)
        assertEquals(75, data.cloudCover)
    }

    // ==================== SvgChartGenerator Tests ====================

    @Test
    fun `generate returns empty SVG for empty data`() {
        val generator = SvgChartGenerator()
        val svg = generator.generate(
            data = emptyList(),
            nowIndex = 0,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.light,
            width = 800.0,
            height = 400.0
        )

        assertTrue(svg.startsWith("<svg"))
        assertTrue(svg.contains("viewBox=\"0 0 800 400\""))
        assertTrue(svg.endsWith("</svg>"))
    }

    @Test
    fun `generate produces valid SVG structure`() {
        val generator = SvgChartGenerator()
        val data = createTestData(24)

        val svg = generator.generate(
            data = data,
            nowIndex = 6,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.light,
            width = 800.0,
            height = 400.0
        )

        // Check basic SVG structure
        assertTrue(svg.startsWith("<svg xmlns=\"http://www.w3.org/2000/svg\""))
        assertTrue(svg.contains("<defs>"))
        assertTrue(svg.contains("</defs>"))
        assertTrue(svg.contains("tempGradient"))
        assertTrue(svg.contains("</svg>"))
    }

    @Test
    fun `generate includes now indicator line`() {
        val generator = SvgChartGenerator()
        val data = createTestData(24)

        val svg = generator.generate(
            data = data,
            nowIndex = 6,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.light,
            width = 800.0,
            height = 400.0
        )

        // Should have a vertical line for "now" indicator
        assertTrue(svg.contains("<line"))
        assertTrue(svg.contains("stroke=\"${SvgChartColors.light.nowIndicator.toHex()}\""))
    }

    @Test
    fun `generate uses Fahrenheit when specified`() {
        val generator = SvgChartGenerator()
        // Create data with 20°C temperature
        val data = listOf(
            HourlyData(System.currentTimeMillis(), 20.0, 0.0, 0),
            HourlyData(System.currentTimeMillis() + 3600000, 25.0, 0.0, 0),
            HourlyData(System.currentTimeMillis() + 7200000, 30.0, 0.0, 0)
        )

        val svgCelsius = generator.generate(
            data = data,
            nowIndex = 1,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.light,
            width = 800.0,
            height = 400.0,
            usesFahrenheit = false
        )

        val svgFahrenheit = generator.generate(
            data = data,
            nowIndex = 1,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.light,
            width = 800.0,
            height = 400.0,
            usesFahrenheit = true
        )

        // Celsius should show 20, 25, 30
        assertTrue(svgCelsius.contains(">20<") || svgCelsius.contains(">25<") || svgCelsius.contains(">30<"))

        // Fahrenheit should show 68, 77, 86 (20*9/5+32=68, etc.)
        assertTrue(svgFahrenheit.contains(">68<") || svgFahrenheit.contains(">77<") || svgFahrenheit.contains(">86<"))
    }

    @Test
    fun `generate handles dark theme colors`() {
        val generator = SvgChartGenerator()
        val data = createTestData(24)

        val svg = generator.generate(
            data = data,
            nowIndex = 6,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.dark,
            width = 800.0,
            height = 400.0
        )

        assertTrue(svg.contains(SvgChartColors.dark.temperatureLine.toHex()))
    }

    @Test
    fun `generate respects width and height`() {
        val generator = SvgChartGenerator()
        val data = createTestData(24)

        val svg = generator.generate(
            data = data,
            nowIndex = 6,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.light,
            width = 1200.0,
            height = 600.0
        )

        assertTrue(svg.contains("viewBox=\"0 0 1200 600\""))
    }

    @Test
    fun `generate includes precipitation bars when data has precipitation`() {
        val generator = SvgChartGenerator()
        val data = listOf(
            HourlyData(System.currentTimeMillis(), 15.0, 5.0, 50),  // 5mm precipitation
            HourlyData(System.currentTimeMillis() + 3600000, 16.0, 0.0, 50),
            HourlyData(System.currentTimeMillis() + 7200000, 17.0, 2.0, 50)
        )

        val svg = generator.generate(
            data = data,
            nowIndex = 1,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.light,
            width = 800.0,
            height = 400.0
        )

        // Should have precipitation gradient
        assertTrue(svg.contains("precipGradient"))
    }

    @Test
    fun `generate handles single data point`() {
        val generator = SvgChartGenerator()
        val data = listOf(
            HourlyData(System.currentTimeMillis(), 15.0, 0.0, 50)
        )

        // Should not crash
        val svg = generator.generate(
            data = data,
            nowIndex = 0,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.light,
            width = 800.0,
            height = 400.0
        )

        assertTrue(svg.startsWith("<svg"))
        assertTrue(svg.endsWith("</svg>"))
    }

    @Test
    fun `generate disables past fade when specified`() {
        val generator = SvgChartGenerator()
        val data = createTestData(24)

        val svgWithFade = generator.generate(
            data = data,
            nowIndex = 6,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.light,
            width = 800.0,
            height = 400.0,
            usePastFade = true
        )

        val svgWithoutFade = generator.generate(
            data = data,
            nowIndex = 6,
            latitude = 52.52,
            longitude = 13.405,
            colors = SvgChartColors.light,
            width = 800.0,
            height = 400.0,
            usePastFade = false
        )

        assertTrue(svgWithFade.contains("pastFadeMask"))
        assertFalse(svgWithoutFade.contains("pastFadeMask"))
    }

    // ==================== Helper Methods ====================

    @Test
    fun `generate writes locale-independent numbers`() {
        // SVG numbers must use '.' as the decimal separator. String.format
        // follows the default locale, so under comma-decimal locales (uk, de,
        // fr, ...) the temperature fill's "0.28" became "0,28", which AndroidSVG
        // reads as 0 — the fill under the temperature line vanished.
        val saved = Locale.getDefault()
        try {
            for (tag in listOf("uk", "de", "fr")) {
                Locale.setDefault(Locale.forLanguageTag(tag))
                for ((colors, fill) in listOf(SvgChartColors.light to "0.10", SvgChartColors.dark to "0.28")) {
                    val svg = SvgChartGenerator().generate(
                        data = createTestData(24),
                        nowIndex = 6,
                        latitude = 52.52,
                        longitude = 13.405,
                        colors = colors,
                        width = 800.0,
                        height = 400.0
                    )

                    val commaDecimal = Regex("""="[^"]*\d,\d[^"]*"""").find(svg)
                    assertNull("comma decimal in an attribute under $tag: ${commaDecimal?.value}", commaDecimal)
                    assertTrue("temperature fill missing under $tag", svg.contains("stop-opacity=\"$fill\""))
                }
            }
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test
    fun `temperatureColorAt follows the scale and clamps at both ends`() {
        val light = ChartSchemes.thermalLight
        assertEquals("#1a6684", light.temperatureColorAt(0.0).toHex())
        assertEquals("#b8305f", light.temperatureColorAt(40.0).toHex())
        // Halfway between the 0°C and 20°C stops, mixed per channel.
        assertEquals("#365f77", light.temperatureColorAt(10.0).toHex())
        assertEquals("#3b3a8f", light.temperatureColorAt(-66.0).toHex())
        assertEquals("#b8305f", light.temperatureColorAt(45.0).toHex())
    }

    @Test
    fun `temperatureColorAt without a scale is the line colour`() {
        val colors = SvgChartColors.light
        assertEquals(colors.temperatureLine, colors.temperatureColorAt(-20.0))
        assertEquals(colors.temperatureLine, colors.temperatureColorAt(35.0))
    }

    @Test
    fun `generate colour-codes the temperature only for scaled palettes`() {
        fun svgFor(colors: SvgChartColors) = SvgChartGenerator().generate(
            data = createTestData(24),
            nowIndex = 6,
            latitude = 52.52,
            longitude = 13.405,
            colors = colors,
            width = 800.0,
            height = 400.0
        )

        val scaled = svgFor(ChartSchemes.thermalLight)
        // Absolute mapping needs chart coordinates, not the path's bounding box.
        assertTrue(scaled.contains("""<linearGradient id="tempLineGradient" gradientUnits="userSpaceOnUse""""))
        assertTrue(scaled.contains("""stroke="url(#tempLineGradient)""""))
        assertTrue(scaled.contains("""fill="url(#tempScaleFill)""""))

        val plain = svgFor(SvgChartColors.light)
        assertFalse(plain.contains("tempLineGradient"))
        assertTrue(plain.contains("""stroke="${SvgChartColors.light.temperatureLine.toHex()}""""))
    }

    @Test
    fun `colour-coded output stays locale-independent`() {
        val saved = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("uk"))
            val svg = SvgChartGenerator().generate(
                data = createTestData(24),
                nowIndex = 6,
                latitude = 52.52,
                longitude = 13.405,
                colors = ChartSchemes.thermalDark,
                width = 800.0,
                height = 400.0
            )
            val commaDecimal = Regex("""="[^"]*\d,\d[^"]*"""").find(svg)
            assertNull("comma decimal in an attribute: ${commaDecimal?.value}", commaDecimal)
        } finally {
            Locale.setDefault(saved)
        }
    }

    @Test
    fun `ChartSchemes thermal temperature scale matches the Dart mirror`() {
        // ChartScheme.temperatureScale (scheme_service.dart) repeats these so
        // the big reading in the card header matches the line; pinned there too.
        fun stops(colors: SvgChartColors) = colors.temperatureScale!!.map { (t, c) -> t to c.toHex() }
        assertEquals(
            listOf(-20.0 to "#3b3a8f", 0.0 to "#1a6684", 20.0 to "#52586a", 40.0 to "#b8305f"),
            stops(ChartSchemes.thermalLight)
        )
        assertEquals(
            listOf(-20.0 to "#b8a8f0", 0.0 to "#8fc9e0", 20.0 to "#d8d4dc", 40.0 to "#f2708a"),
            stops(ChartSchemes.thermalDark)
        )
    }

    @Test
    fun `daylightColorAt follows the scale and clamps at both ends`() {
        val light = ChartSchemes.thermalLight
        assertEquals("#d9864f", light.daylightColorAt(-20.0).toHex())
        assertEquals("#ff8f00", light.daylightColorAt(40.0).toHex())
        // A third of the way from -20°C to +40°C, mixed per channel.
        assertEquals("#e68935", light.daylightColorAt(0.0).toHex())
        assertEquals("#d9864f", light.daylightColorAt(-66.0).toHex())
        assertEquals("#ff8f00", light.daylightColorAt(48.0).toHex())
    }

    @Test
    fun `daylightColorAt without a scale is the daylight bar colour`() {
        val colors = SvgChartColors.light
        assertEquals(colors.daylightBar, colors.daylightColorAt(-20.0))
        assertEquals(colors.daylightBar, colors.daylightColorAt(40.0))
    }

    @Test
    fun `generate colour-codes daylight bars only for scaled palettes`() {
        fun svgFor(colors: SvgChartColors) = SvgChartGenerator().generate(
            data = createTestData(24),
            nowIndex = 6,
            latitude = 52.52,
            longitude = 13.405,
            colors = colors,
            width = 800.0,
            height = 400.0
        )

        val scaled = svgFor(ChartSchemes.thermalLight)
        val bucketDefs = Regex("""<linearGradient id="daylightT""").findAll(scaled).count()
        assertTrue("expected per-temperature sun gradients", bucketDefs > 0)
        // Bucketed, so far fewer gradients than hours.
        assertTrue("too many sun gradients: $bucketDefs", bucketDefs < 24)
        assertTrue(scaled.contains("""fill="url(#daylightT"""))

        val plain = svgFor(SvgChartColors.light)
        assertFalse(plain.contains("daylightT"))
    }

    @Test
    fun `ChartSchemes thermal daylight scale matches the Dart mirror`() {
        // ChartScheme.daylightScale (scheme_service.dart) repeats these so the
        // legend's sun matches the bars; pinned there too.
        fun stops(colors: SvgChartColors) = colors.daylightScale!!.map { (t, c) -> t to c.toHex() }
        assertEquals(listOf(-20.0 to "#d9864f", 40.0 to "#ff8f00"), stops(ChartSchemes.thermalLight))
        assertEquals(listOf(-20.0 to "#e09060", 40.0 to "#f2d45c"), stops(ChartSchemes.thermalDark))
    }

    @Test
    fun `atTemperature moves the ground and its halo along the scale`() {
        val light = ChartSchemes.thermalLight
        assertEquals("#e4eaef", light.atTemperature(45.0).cardBackground.toHex())
        assertEquals("#efe7ea", light.atTemperature(-30.0).outlineColor.toHex())
        assertEquals("#e9e9e9", light.atTemperature(20.0).cardBackground.toHex())
        val dark = ChartSchemes.thermalDark
        for ((celsius, hex) in listOf(-20.0 to "#1d0c0c", -10.0 to "#1a0d0d", 20.0 to "#111111", 40.0 to "#0b111e", -66.0 to "#1d0c0c")) {
            val resolved = dark.atTemperature(celsius)
            assertEquals("ground at $celsius", hex, resolved.cardBackground.toHex())
            // The halo behind line and labels must match the ground it sits on.
            assertEquals("halo at $celsius", hex, resolved.outlineColor.toHex())
        }
    }

    @Test
    fun `atTemperature leaves palettes without a ground scale unchanged`() {
        for (palette in listOf(SvgChartColors.light, SvgChartColors.dark, ChartSchemes.contrastLight, ChartSchemes.contrastDark)) {
            assertEquals(palette, palette.atTemperature(-30.0))
            assertEquals(palette, palette.atTemperature(40.0))
        }
    }

    @Test
    fun `generate paints the ground for the current hour's temperature`() {
        val now = System.currentTimeMillis()
        fun svgAt(celsius: Double) = SvgChartGenerator().generate(
            data = (0 until 24).map { HourlyData(now + it * 3_600_000L, celsius, 0.0, 50) },
            nowIndex = 6, latitude = 52.52, longitude = 13.405,
            colors = ChartSchemes.thermalDark, width = 800.0, height = 400.0
        )
        assertTrue(svgAt(-25.0).contains("""height="400" fill="#1d0c0c"/>"""))
        assertTrue(svgAt(45.0).contains("""height="400" fill="#0b111e"/>"""))
        // The halo follows: no stroke in the fixed plum is left on a moved ground.
        assertFalse(svgAt(45.0).contains("""stroke="#2a1d2e""""))
    }

    @Test
    fun `ChartSchemes thermal ground scale matches the Dart mirror`() {
        // ChartScheme.groundScale (scheme_service.dart) repeats these so the
        // in-app card matches the painted ground; pinned there too.
        assertEquals(
            listOf(-20.0 to "#efe7ea", 20.0 to "#e9e9e9", 40.0 to "#e4eaef"),
            ChartSchemes.thermalLight.groundScale!!.map { (t, c) -> t to c.toHex() }
        )
        assertEquals(
            listOf(-20.0 to "#1d0c0c", 20.0 to "#111111", 40.0 to "#0b111e"),
            ChartSchemes.thermalDark.groundScale!!.map { (t, c) -> t to c.toHex() }
        )
    }

    @Test
    fun `colour scales must have two strictly ascending stops`() {
        val c = SvgColor(0x11, 0x22, 0x33)
        val base = SvgChartColors.light
        fun rejects(scale: List<Pair<Double, SvgColor>>) {
            for (build in listOf<() -> Unit>(
                { base.copy(temperatureScale = scale) },
                { base.copy(daylightScale = scale) },
                { base.copy(groundScale = scale) }
            )) {
                try {
                    build()
                    fail("accepted invalid scale ${scale.map { it.first }}")
                } catch (expected: IllegalArgumentException) {
                }
            }
        }
        rejects(emptyList())
        rejects(listOf(0.0 to c))                 // single stop: zero span
        rejects(listOf(0.0 to c, 0.0 to c))       // duplicate: zero span
        rejects(listOf(10.0 to c, 0.0 to c))      // descending
        // Valid scales still construct.
        base.copy(temperatureScale = listOf(-20.0 to c, 40.0 to c))
    }

    private fun createTestData(count: Int): List<HourlyData> {
        val baseTime = System.currentTimeMillis()
        return (0 until count).map { i ->
            HourlyData(
                time = baseTime + i * 3600_000L,
                temperature = 10.0 + i * 0.5,  // Gradually increasing temp
                precipitation = if (i % 5 == 0) 1.0 else 0.0,  // Some precipitation
                cloudCover = (i * 10) % 100  // Varying cloud cover
            )
        }
    }
}
