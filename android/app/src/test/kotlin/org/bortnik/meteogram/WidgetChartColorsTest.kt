package org.bortnik.meteogram

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Tests the single point where a chart palette is chosen: the stored scheme
 * must win over Material You, and the default must leave that path alone.
 */
@RunWith(RobolectricTestRunner::class)
class WidgetChartColorsTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        prefs().edit().clear().commit()
    }

    private fun prefs() =
        context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)

    private fun setScheme(id: String?) {
        prefs().edit().apply {
            if (id == null) remove(WidgetUtils.KEY_COLOR_SCHEME)
            else putString(WidgetUtils.KEY_COLOR_SCHEME, id)
        }.commit()
    }

    @Test
    fun `absent scheme falls back to the built-in presets`() {
        // Robolectric reports no Material You colours, so the base presets are
        // what the default path yields here.
        assertEquals(SvgChartColors.light, WidgetChartColors.get(context, isLight = true))
        assertEquals(SvgChartColors.dark, WidgetChartColors.get(context, isLight = false))
    }

    @Test
    fun `default scheme leaves the Material You path in place`() {
        setScheme(ChartSchemes.DEFAULT)

        assertEquals(SvgChartColors.light, WidgetChartColors.get(context, isLight = true))
        assertEquals(SvgChartColors.dark, WidgetChartColors.get(context, isLight = false))
    }

    @Test
    fun `arctic scheme is applied for both themes`() {
        setScheme(ChartSchemes.ARCTIC)

        assertEquals(ChartSchemes.arcticLight, WidgetChartColors.get(context, isLight = true))
        assertEquals(ChartSchemes.arcticDark, WidgetChartColors.get(context, isLight = false))
    }

    @Test
    fun `high-contrast scheme is applied for both themes`() {
        setScheme(ChartSchemes.CONTRAST)

        assertEquals(ChartSchemes.contrastLight, WidgetChartColors.get(context, isLight = true))
        assertEquals(ChartSchemes.contrastDark, WidgetChartColors.get(context, isLight = false))
    }

    @Test
    fun `unknown scheme id falls back instead of failing`() {
        setScheme("scheme-from-a-newer-version")

        assertEquals(SvgChartColors.light, WidgetChartColors.get(context, isLight = true))
    }

    @Test
    fun `switching back to default restores the presets`() {
        setScheme(ChartSchemes.CONTRAST)
        assertNotEquals(SvgChartColors.light, WidgetChartColors.get(context, isLight = true))

        setScheme(ChartSchemes.DEFAULT)
        assertEquals(SvgChartColors.light, WidgetChartColors.get(context, isLight = true))
    }
}
