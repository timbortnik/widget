package org.bortnik.meteogram

import android.content.Context
import android.content.Intent
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * Unit tests for WidgetAlarmReceiver.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class WidgetAlarmReceiverTest {

    private lateinit var context: Context
    private lateinit var receiver: WidgetAlarmReceiver

    @Before
    fun setup() {
        context = RuntimeEnvironment.getApplication()
        receiver = WidgetAlarmReceiver()

        // Clear SharedPreferences
        context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
    }

    @Test
    fun `ACTION_ALARM_UPDATE constant is correct`() {
        assertEquals(
            "org.bortnik.meteogram.ACTION_ALARM_UPDATE",
            WidgetAlarmReceiver.ACTION_ALARM_UPDATE
        )
    }

    @Test
    fun `onReceive handles correct action without crashing`() {
        val intent = Intent(WidgetAlarmReceiver.ACTION_ALARM_UPDATE)

        // Should not throw
        receiver.onReceive(context, intent)
    }

    @Test
    fun `onReceive ignores unexpected action`() {
        val intent = Intent("com.example.UNEXPECTED_ACTION")

        // Should not throw - unexpected actions are logged and ignored
        receiver.onReceive(context, intent)
    }

    @Test
    fun `onReceive ignores null action`() {
        val intent = Intent()

        // Should not throw
        receiver.onReceive(context, intent)
    }

    @Test
    fun `receiver can be instantiated`() {
        val newReceiver = WidgetAlarmReceiver()
        assertNotNull(newReceiver)
    }

    @Test
    fun `onReceive with stale data does not crash`() {
        // Set weather data to be stale (20 minutes ago)
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val oldTime = System.currentTimeMillis() - (20 * 60 * 1000)
        prefs.edit()
            .putString(WidgetUtils.KEY_LAST_WEATHER_UPDATE, oldTime.toString())
            .commit()

        val intent = Intent(WidgetAlarmReceiver.ACTION_ALARM_UPDATE)

        // Should not throw - will attempt fetch (which fails without network, but doesn't crash)
        receiver.onReceive(context, intent)
    }

    @Test
    fun `onReceive with fresh data does not crash`() {
        // Set weather data to be fresh (5 minutes ago)
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val recentTime = System.currentTimeMillis() - (5 * 60 * 1000)
        prefs.edit()
            .putString(WidgetUtils.KEY_LAST_WEATHER_UPDATE, recentTime.toString())
            .commit()

        val intent = Intent(WidgetAlarmReceiver.ACTION_ALARM_UPDATE)

        // Should not throw
        receiver.onReceive(context, intent)
    }
}
