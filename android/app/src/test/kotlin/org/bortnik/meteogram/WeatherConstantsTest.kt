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
}
