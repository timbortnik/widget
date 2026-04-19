package org.bortnik.meteogram

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for WeatherConstants.
 *
 * These tests verify that constants match the expected values
 * and maintain consistency with the Dart side.
 */
class WeatherConstantsTest {

    @Test
    fun `PAST_HOURS is 6`() {
        assertEquals(6, WeatherConstants.PAST_HOURS)
    }

    @Test
    fun `FORECAST_HOURS is 46`() {
        assertEquals(46, WeatherConstants.FORECAST_HOURS)
    }

    @Test
    fun `DISPLAY_RANGE_HOURS equals PAST_HOURS plus FORECAST_HOURS`() {
        assertEquals(
            WeatherConstants.PAST_HOURS + WeatherConstants.FORECAST_HOURS,
            WeatherConstants.DISPLAY_RANGE_HOURS
        )
    }

    @Test
    fun `DISPLAY_RANGE_HOURS is 52`() {
        // 6 past + 46 future = 52 total
        assertEquals(52, WeatherConstants.DISPLAY_RANGE_HOURS)
    }

    @Test
    fun `constants are positive`() {
        assertTrue(WeatherConstants.PAST_HOURS > 0)
        assertTrue(WeatherConstants.FORECAST_HOURS > 0)
        assertTrue(WeatherConstants.DISPLAY_RANGE_HOURS > 0)
    }

    @Test
    fun `DISPLAY_RANGE_HOURS covers about 2 days`() {
        // 52 hours is a bit over 2 days (48 hours)
        assertTrue(WeatherConstants.DISPLAY_RANGE_HOURS >= 48)
        assertTrue(WeatherConstants.DISPLAY_RANGE_HOURS <= 72)
    }

    @Test
    fun `WEEKLY_FORECAST_HOURS is 7 days`() {
        assertEquals(7 * 24, WeatherConstants.WEEKLY_FORECAST_HOURS)
    }

    @Test
    fun `WEEKLY_PAST_HOURS places now-line at same fraction as 48h chart`() {
        // SvgChartGenerator positions points as index/(size-1), so both charts
        // must place the now-line at the same fraction of width. With integer
        // hours, the rounding error bound is ~0.5 hours over a smaller forecast
        // window, so allow 0.003 (≈3px on a 1000px chart).
        val hourlyFraction =
            WeatherConstants.PAST_HOURS.toDouble() /
                (WeatherConstants.DISPLAY_RANGE_HOURS - 1)
        val weeklyFraction =
            WeatherConstants.WEEKLY_PAST_HOURS.toDouble() /
                (WeatherConstants.WEEKLY_RANGE_HOURS - 1)
        assertEquals(hourlyFraction, weeklyFraction, 0.003)
    }

    @Test
    fun `WEEKLY_RANGE_HOURS equals WEEKLY_PAST_HOURS plus WEEKLY_FORECAST_HOURS`() {
        assertEquals(
            WeatherConstants.WEEKLY_PAST_HOURS + WeatherConstants.WEEKLY_FORECAST_HOURS,
            WeatherConstants.WEEKLY_RANGE_HOURS
        )
    }
}
