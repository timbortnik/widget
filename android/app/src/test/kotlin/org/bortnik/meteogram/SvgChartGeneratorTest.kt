package org.bortnik.meteogram

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
        assertEquals(ChartSchemes.arcticLight, ChartSchemes.palette(ChartSchemes.ARCTIC, isLight = true))
        assertEquals(ChartSchemes.arcticDark, ChartSchemes.palette(ChartSchemes.ARCTIC, isLight = false))
        assertEquals(ChartSchemes.contrastLight, ChartSchemes.palette(ChartSchemes.CONTRAST, isLight = true))
        assertEquals(ChartSchemes.contrastDark, ChartSchemes.palette(ChartSchemes.CONTRAST, isLight = false))
    }

    @Test
    fun `ChartSchemes ids lists every scheme the picker offers`() {
        assertEquals(listOf("default", "arctic", "contrast"), ChartSchemes.ids)
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
        assertNotEquals(ChartSchemes.arcticLight, ChartSchemes.arcticDark)
        assertNotEquals(ChartSchemes.contrastLight, ChartSchemes.contrastDark)
    }

    @Test
    fun `ChartSchemes bars stay blue-vs-amber for colour-vision safety`() {
        // Precipitation and daylight are the only same-shape series, so they
        // must never be told apart by a red/green distinction.
        for (palette in listOf(
            ChartSchemes.arcticLight, ChartSchemes.arcticDark,
            ChartSchemes.contrastLight, ChartSchemes.contrastDark
        )) {
            val rain = palette.precipitationBar
            val sun = palette.daylightBar
            assertTrue("precipitation should read as blue: ${rain.toHex()}", rain.b > rain.r)
            assertTrue("daylight should read as amber: ${sun.toHex()}", sun.r > sun.b)
        }
    }

    @Test
    fun `ChartSchemes text contrasts its own background`() {
        // Labels are drawn over the card, so a scheme whose text and ground sit
        // at the same luminance is unreadable regardless of hue.
        fun luminance(c: SvgColor) = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

        for (palette in listOf(
            ChartSchemes.arcticLight, ChartSchemes.arcticDark,
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
