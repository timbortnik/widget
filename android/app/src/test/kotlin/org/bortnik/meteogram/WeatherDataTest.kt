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

    @Test
    fun `getDisplayRange returns all data when less than DISPLAY_RANGE_HOURS`() {
        val weatherData = createWeatherData(10)

        val displayRange = weatherData.getDisplayRange()

        assertEquals(10, displayRange.size)
    }

    @Test
    fun `getDisplayRange limits to DISPLAY_RANGE_HOURS`() {
        val weatherData = createWeatherData(100)

        val displayRange = weatherData.getDisplayRange()

        assertEquals(WeatherConstants.DISPLAY_RANGE_HOURS, displayRange.size)
    }

    @Test
    fun `getDisplayRange returns empty list for empty hourly data`() {
        val weatherData = WeatherData(
            timezone = "UTC",
            latitude = 0.0,
            longitude = 0.0,
            hourly = emptyList(),
            fetchedAt = 0L
        )

        val displayRange = weatherData.getDisplayRange()

        assertTrue(displayRange.isEmpty())
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
