package org.bortnik.meteogram

import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for WeatherData class.
 */
class WeatherDataTest {

    private fun createHourlyData(count: Int, startTimeMs: Long = 0L): List<HourlyData> {
        return (0 until count).map { i ->
            HourlyData(
                time = startTimeMs + i * 3600_000L, // 1 hour apart
                temperature = 10.0 + i,
                precipitation = 0.0,
                cloudCover = 0
            )
        }
    }

    private fun createWeatherData(hourlyCount: Int): WeatherData {
        return WeatherData(
            timezone = "UTC",
            latitude = 52.52,
            longitude = 13.405,
            hourly = createHourlyData(hourlyCount),
            fetchedAt = System.currentTimeMillis()
        )
    }

    /** Build weather data where "now" sits at the given hour offset from epoch. */
    private fun weatherCenteredOnNow(pastHours: Int, forecastHours: Int): WeatherData {
        val now = System.currentTimeMillis()
        val hourMs = 3600_000L
        val roundedNow = (now / hourMs) * hourMs
        val hourly = (-pastHours..forecastHours).map { offset ->
            HourlyData(
                time = roundedNow + offset * hourMs,
                temperature = 10.0 + offset,
                precipitation = 0.0,
                cloudCover = 0
            )
        }
        return WeatherData(
            timezone = "UTC",
            latitude = 52.52,
            longitude = 13.405,
            hourly = hourly,
            fetchedAt = now
        )
    }

    @Test
    fun `getHourlyView returns 48h window around now`() {
        // Full cache: 48h past + 336h forecast = 385 entries.
        val weatherData = weatherCenteredOnNow(pastHours = 48, forecastHours = 336)

        val view = weatherData.getHourlyView()

        assertEquals(WeatherConstants.DISPLAY_RANGE_HOURS, view.data.size)
        assertEquals(WeatherConstants.PAST_HOURS, view.nowIndex)
    }

    @Test
    fun `getWeeklyView returns proportional past plus 14d forecast`() {
        val weatherData = weatherCenteredOnNow(pastHours = 48, forecastHours = 336)

        val view = weatherData.getWeeklyView()

        assertEquals(WeatherConstants.WEEKLY_RANGE_HOURS, view.data.size)
        assertEquals(WeatherConstants.WEEKLY_PAST_HOURS, view.nowIndex)
    }

    @Test
    fun `getHourlyView returns empty view for empty data`() {
        val weatherData = WeatherData(
            timezone = "UTC",
            latitude = 0.0,
            longitude = 0.0,
            hourly = emptyList(),
            fetchedAt = 0L
        )

        val view = weatherData.getHourlyView()

        assertTrue(view.data.isEmpty())
        assertEquals(0, view.nowIndex)
    }

    @Test
    fun `getWeeklyView returns empty view for empty data`() {
        val weatherData = WeatherData(
            timezone = "UTC",
            latitude = 0.0,
            longitude = 0.0,
            hourly = emptyList(),
            fetchedAt = 0L
        )

        val view = weatherData.getWeeklyView()

        assertTrue(view.data.isEmpty())
        assertEquals(0, view.nowIndex)
    }

    @Test
    fun `getNowIndex returns 0 for empty hourly data`() {
        val weatherData = WeatherData(
            timezone = "UTC",
            latitude = 0.0,
            longitude = 0.0,
            hourly = emptyList(),
            fetchedAt = 0L
        )

        val nowIndex = weatherData.getNowIndex()

        assertEquals(0, nowIndex)
    }

    @Test
    fun `getNowIndex returns valid index within bounds`() {
        val weatherData = createWeatherData(52)

        val nowIndex = weatherData.getNowIndex()

        assertTrue("nowIndex should be >= 0", nowIndex >= 0)
        assertTrue("nowIndex should be < hourly.size", nowIndex < weatherData.hourly.size)
    }

    @Test
    fun `getCurrentTemperature returns null for empty hourly data`() {
        val weatherData = WeatherData(
            timezone = "UTC",
            latitude = 0.0,
            longitude = 0.0,
            hourly = emptyList(),
            fetchedAt = 0L
        )

        val temp = weatherData.getCurrentTemperature()

        assertNull(temp)
    }

    @Test
    fun `getCurrentTemperature returns temperature at nowIndex`() {
        // Create data with current time in the middle
        val now = System.currentTimeMillis()
        val hourMs = 3600_000L

        // Round now to nearest hour
        val roundedNow = (now / hourMs) * hourMs

        // Create hourly data centered around current time
        val hourlyData = (-6..46).map { offset ->
            HourlyData(
                time = roundedNow + offset * hourMs,
                temperature = 20.0 + offset, // Temperature varies with hour
                precipitation = 0.0,
                cloudCover = 0
            )
        }

        val weatherData = WeatherData(
            timezone = "UTC",
            latitude = 52.52,
            longitude = 13.405,
            hourly = hourlyData,
            fetchedAt = now
        )

        val temp = weatherData.getCurrentTemperature()

        assertNotNull(temp)
        // Temperature should be around 20.0 (offset 0 = current hour)
        // Allow some variance due to time rounding
        assertTrue("Temperature should be reasonable", temp!! in 14.0..26.0)
    }
}
