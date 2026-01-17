package org.bortnik.meteogram

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Unit tests for WidgetUtils using Robolectric.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class WidgetUtilsTest {

    private lateinit var context: Context

    @Before
    fun setUp() {
        context = ApplicationProvider.getApplicationContext()
        // Clear SharedPreferences before each test
        context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
    }

    @Test
    fun `isWeatherDataStale returns true when no last update`() {
        val isStale = WidgetUtils.isWeatherDataStale(context)

        assertTrue("Should be stale when no last update exists", isStale)
    }

    @Test
    fun `isWeatherDataStale returns true when data is old`() {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val oldTime = System.currentTimeMillis() - (20 * 60 * 1000) // 20 minutes ago
        prefs.edit()
            .putString(WidgetUtils.KEY_LAST_WEATHER_UPDATE, oldTime.toString())
            .commit()

        val isStale = WidgetUtils.isWeatherDataStale(context)

        assertTrue("Should be stale when data is > 15 min old", isStale)
    }

    @Test
    fun `isWeatherDataStale returns false when data is fresh`() {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val recentTime = System.currentTimeMillis() - (5 * 60 * 1000) // 5 minutes ago
        prefs.edit()
            .putString(WidgetUtils.KEY_LAST_WEATHER_UPDATE, recentTime.toString())
            .commit()

        val isStale = WidgetUtils.isWeatherDataStale(context)

        assertFalse("Should not be stale when data is < 15 min old", isStale)
    }

    @Test
    fun `isWeatherDataStale returns true at exactly 15 minutes`() {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val exactlyStaleTime = System.currentTimeMillis() - WidgetUtils.STALE_THRESHOLD_MS - 1
        prefs.edit()
            .putString(WidgetUtils.KEY_LAST_WEATHER_UPDATE, exactlyStaleTime.toString())
            .commit()

        val isStale = WidgetUtils.isWeatherDataStale(context)

        assertTrue("Should be stale when data is exactly at threshold", isStale)
    }

    @Test
    fun `isRerenderNeeded returns true when never rendered`() {
        val isNeeded = WidgetUtils.isRerenderNeeded(context)

        assertTrue("Should need re-render when never rendered before", isNeeded)
    }

    @Test
    fun `isRerenderNeeded returns true when weather updated since last render`() {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        prefs.edit()
            .putLong(WidgetUtils.KEY_LAST_RENDER_TIME, now - 60_000) // 1 min ago
            .putString(WidgetUtils.KEY_LAST_WEATHER_UPDATE, now.toString()) // Just now
            .commit()

        val isNeeded = WidgetUtils.isRerenderNeeded(context)

        assertTrue("Should need re-render when weather updated since last render", isNeeded)
    }

    @Test
    fun `isRerenderNeeded returns false when recently rendered and no weather update`() {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()

        prefs.edit()
            .putLong(WidgetUtils.KEY_LAST_RENDER_TIME, now) // Just now
            .putString(WidgetUtils.KEY_LAST_WEATHER_UPDATE, (now - 60_000).toString()) // 1 min before render
            .commit()

        val isNeeded = WidgetUtils.isRerenderNeeded(context)

        assertFalse("Should not need re-render when recently rendered", isNeeded)
    }

    @Test
    fun `isRerenderNeeded returns true when 30-min boundary crossed`() {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val halfHourMs = 30 * 60 * 1000L

        // Set last render to previous 30-min slot
        val lastRenderTime = ((now / halfHourMs) - 1) * halfHourMs

        prefs.edit()
            .putLong(WidgetUtils.KEY_LAST_RENDER_TIME, lastRenderTime)
            .putString(WidgetUtils.KEY_LAST_WEATHER_UPDATE, (lastRenderTime - 60_000).toString())
            .commit()

        val isNeeded = WidgetUtils.isRerenderNeeded(context)

        assertTrue("Should need re-render when 30-min boundary crossed", isNeeded)
    }

    @Test
    fun `updateLastRenderTime updates the timestamp`() {
        val before = System.currentTimeMillis()

        WidgetUtils.updateLastRenderTime(context)

        val after = System.currentTimeMillis()
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val savedTime = prefs.getLong(WidgetUtils.KEY_LAST_RENDER_TIME, 0)

        assertTrue("Saved time should be >= before", savedTime >= before)
        assertTrue("Saved time should be <= after", savedTime <= after)
    }

    @Test
    fun `getWidgetDimensions returns defaults when not set`() {
        val (width, height) = WidgetUtils.getWidgetDimensions(context)

        assertEquals(WidgetUtils.DEFAULT_WIDTH_PX, width)
        assertEquals(WidgetUtils.DEFAULT_HEIGHT_PX, height)
    }

    @Test
    fun `getWidgetDimensions returns saved values`() {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putInt(WidgetUtils.KEY_WIDGET_WIDTH_PX, 800)
            .putInt(WidgetUtils.KEY_WIDGET_HEIGHT_PX, 400)
            .commit()

        val (width, height) = WidgetUtils.getWidgetDimensions(context)

        assertEquals(800, width)
        assertEquals(400, height)
    }

    @Test
    fun `getWidgetDimensions returns defaults for invalid values`() {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putInt(WidgetUtils.KEY_WIDGET_WIDTH_PX, 0)
            .putInt(WidgetUtils.KEY_WIDGET_HEIGHT_PX, -1)
            .commit()

        val (width, height) = WidgetUtils.getWidgetDimensions(context)

        assertEquals(WidgetUtils.DEFAULT_WIDTH_PX, width)
        assertEquals(WidgetUtils.DEFAULT_HEIGHT_PX, height)
    }
}
