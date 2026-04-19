package org.bortnik.meteogram

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.shadows.ShadowAlarmManager

/**
 * Unit tests for BootCompletedReceiver.
 */
@RunWith(RobolectricTestRunner::class)
class BootCompletedReceiverTest {

    private lateinit var context: Context
    private lateinit var receiver: BootCompletedReceiver

    @Before
    fun setup() {
        context = RuntimeEnvironment.getApplication()
        receiver = BootCompletedReceiver()

        // Clear SharedPreferences
        context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
    }

    @Test
    fun `onReceive ignores non-BOOT_COMPLETED action`() {
        val intent = Intent("com.example.UNEXPECTED_ACTION")

        // Should not throw
        receiver.onReceive(context, intent)
    }

    @Test
    fun `onReceive ignores null action`() {
        val intent = Intent()

        // Should not throw
        receiver.onReceive(context, intent)
    }

    @Test
    fun `onReceive schedules alarm on boot`() {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val shadowAlarmManager: ShadowAlarmManager = Shadows.shadowOf(alarmManager)

        // No alarm before boot
        assertNull(shadowAlarmManager.nextScheduledAlarm)

        val intent = Intent(Intent.ACTION_BOOT_COMPLETED)
        receiver.onReceive(context, intent)

        // Alarm should be scheduled after boot
        assertNotNull("Alarm should be scheduled after boot", shadowAlarmManager.nextScheduledAlarm)
    }

    @Test
    fun `onReceive with stale data does not crash`() {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val oldTime = System.currentTimeMillis() - (20 * 60 * 1000)
        prefs.edit()
            .putString(WidgetUtils.KEY_LAST_WEATHER_UPDATE, oldTime.toString())
            .commit()

        val intent = Intent(Intent.ACTION_BOOT_COMPLETED)

        // Should not throw — fetch fails without network but doesn't crash
        receiver.onReceive(context, intent)
    }

    @Test
    fun `onReceive with fresh data does not crash`() {
        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
        val recentTime = System.currentTimeMillis() - (5 * 60 * 1000)
        prefs.edit()
            .putString(WidgetUtils.KEY_LAST_WEATHER_UPDATE, recentTime.toString())
            .commit()

        val intent = Intent(Intent.ACTION_BOOT_COMPLETED)

        // Should not throw
        receiver.onReceive(context, intent)
    }

    @Test
    fun `onReceive with no prior data does not crash`() {
        // SharedPreferences are empty — no weather data, no location
        val intent = Intent(Intent.ACTION_BOOT_COMPLETED)

        // Should not throw
        receiver.onReceive(context, intent)
    }
}
