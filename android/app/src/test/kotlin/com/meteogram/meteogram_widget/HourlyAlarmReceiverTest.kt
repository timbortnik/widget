package com.meteogram.meteogram_widget

import org.junit.Test
import org.junit.Assert.*
import java.util.Calendar

/**
 * Unit tests for HourlyAlarmReceiver logic.
 * Tests the hour boundary verification without needing Android Context.
 */
class HourlyAlarmReceiverTest {

    companion object {
        // Mirror the constant from HourlyAlarmReceiver
        private const val MAX_VALID_MINUTE = 30
    }

    /**
     * Tests the hour boundary verification logic.
     * Returns true if we're past the hour boundary (safe to re-render).
     */
    private fun isHourBoundaryValid(minute: Int): Boolean {
        return minute <= MAX_VALID_MINUTE
    }

    @Test
    fun `minute 0 is valid - just past hour boundary`() {
        assertTrue(isHourBoundaryValid(0))
    }

    @Test
    fun `minute 1 is valid - shortly after hour`() {
        assertTrue(isHourBoundaryValid(1))
    }

    @Test
    fun `minute 15 is valid - buffer time`() {
        assertTrue(isHourBoundaryValid(15))
    }

    @Test
    fun `minute 30 is valid - at threshold`() {
        assertTrue(isHourBoundaryValid(30))
    }

    @Test
    fun `minute 31 is invalid - past threshold`() {
        assertFalse(isHourBoundaryValid(31))
    }

    @Test
    fun `minute 45 is invalid - well past threshold`() {
        assertFalse(isHourBoundaryValid(45))
    }

    @Test
    fun `minute 59 is invalid - end of hour`() {
        assertFalse(isHourBoundaryValid(59))
    }

    /**
     * Tests staleness check logic.
     * Returns true if data is stale (should fetch new data).
     */
    private fun isDataStale(lastUpdateMs: Long, currentTimeMs: Long, thresholdMs: Long): Boolean {
        return currentTimeMs - lastUpdateMs > thresholdMs
    }

    @Test
    fun `data is fresh when just updated`() {
        val now = System.currentTimeMillis()
        val thresholdMs = 15 * 60 * 1000L // 15 minutes
        assertFalse(isDataStale(now, now, thresholdMs))
    }

    @Test
    fun `data is fresh at 14 minutes old`() {
        val now = System.currentTimeMillis()
        val lastUpdate = now - (14 * 60 * 1000L)
        val thresholdMs = 15 * 60 * 1000L
        assertFalse(isDataStale(lastUpdate, now, thresholdMs))
    }

    @Test
    fun `data is stale at 16 minutes old`() {
        val now = System.currentTimeMillis()
        val lastUpdate = now - (16 * 60 * 1000L)
        val thresholdMs = 15 * 60 * 1000L
        assertTrue(isDataStale(lastUpdate, now, thresholdMs))
    }

    @Test
    fun `data is stale when never updated`() {
        val now = System.currentTimeMillis()
        val lastUpdate = 0L
        val thresholdMs = 15 * 60 * 1000L
        assertTrue(isDataStale(lastUpdate, now, thresholdMs))
    }

    /**
     * Tests dimension fallback logic.
     * Returns valid dimensions, using fallback if input is invalid.
     */
    private fun getDimensionsWithFallback(width: Int, height: Int): Pair<Int, Int> {
        val finalWidth = if (width <= 0) 1000 else width
        val finalHeight = if (height <= 0) 500 else height
        return Pair(finalWidth, finalHeight)
    }

    @Test
    fun `valid dimensions are preserved`() {
        val (w, h) = getDimensionsWithFallback(1319, 774)
        assertEquals(1319, w)
        assertEquals(774, h)
    }

    @Test
    fun `zero width uses fallback`() {
        val (w, h) = getDimensionsWithFallback(0, 774)
        assertEquals(1000, w)
        assertEquals(774, h)
    }

    @Test
    fun `zero height uses fallback`() {
        val (w, h) = getDimensionsWithFallback(1319, 0)
        assertEquals(1319, w)
        assertEquals(500, h)
    }

    @Test
    fun `both zero uses fallback`() {
        val (w, h) = getDimensionsWithFallback(0, 0)
        assertEquals(1000, w)
        assertEquals(500, h)
    }

    @Test
    fun `negative width uses fallback`() {
        val (w, h) = getDimensionsWithFallback(-100, 774)
        assertEquals(1000, w)
        assertEquals(774, h)
    }

    /**
     * Tests locale string formatting.
     */
    private fun formatLocaleString(locale: java.util.Locale): String {
        return "${locale.language}_${locale.country}"
    }

    @Test
    fun `formats en_US correctly`() {
        val locale = java.util.Locale("en", "US")
        assertEquals("en_US", formatLocaleString(locale))
    }

    @Test
    fun `formats uk_UA correctly`() {
        val locale = java.util.Locale("uk", "UA")
        assertEquals("uk_UA", formatLocaleString(locale))
    }

    @Test
    fun `formats de_DE correctly`() {
        val locale = java.util.Locale("de", "DE")
        assertEquals("de_DE", formatLocaleString(locale))
    }

    /**
     * Tests next hour calculation.
     */
    @Test
    fun `calculates next hour correctly from minute 0`() {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 14)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 15)
        }

        val nextHour = Calendar.getInstance().apply {
            timeInMillis = calendar.timeInMillis
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 15)
            add(Calendar.HOUR_OF_DAY, 1)
        }

        assertEquals(15, nextHour.get(Calendar.HOUR_OF_DAY))
    }

    @Test
    fun `calculates next hour correctly from minute 45`() {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 14)
            set(Calendar.MINUTE, 45)
            set(Calendar.SECOND, 0)
        }

        val nextHour = Calendar.getInstance().apply {
            timeInMillis = calendar.timeInMillis
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 15)
            add(Calendar.HOUR_OF_DAY, 1)
        }

        assertEquals(15, nextHour.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, nextHour.get(Calendar.MINUTE))
        assertEquals(15, nextHour.get(Calendar.SECOND))
    }
}
