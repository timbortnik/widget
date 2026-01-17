package org.bortnik.meteogram

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowAlarmManager
import org.robolectric.shadows.ShadowPendingIntent

/**
 * Unit tests for WidgetAlarmScheduler.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class WidgetAlarmSchedulerTest {

    private lateinit var context: Context
    private lateinit var alarmManager: AlarmManager
    private lateinit var shadowAlarmManager: ShadowAlarmManager

    @Before
    fun setup() {
        context = RuntimeEnvironment.getApplication()
        alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        shadowAlarmManager = Shadows.shadowOf(alarmManager)
    }

    @Test
    fun `schedule creates alarm with correct interval`() {
        WidgetAlarmScheduler.schedule(context)

        val scheduledAlarm = shadowAlarmManager.nextScheduledAlarm
        assertNotNull("Alarm should be scheduled", scheduledAlarm)

        // Check interval is 15 minutes
        assertEquals(AlarmManager.INTERVAL_FIFTEEN_MINUTES, scheduledAlarm!!.interval)
    }

    @Test
    fun `schedule uses ELAPSED_REALTIME type`() {
        WidgetAlarmScheduler.schedule(context)

        val scheduledAlarm = shadowAlarmManager.nextScheduledAlarm
        assertNotNull(scheduledAlarm)

        // ELAPSED_REALTIME = doesn't wake device
        assertEquals(AlarmManager.ELAPSED_REALTIME, scheduledAlarm!!.type)
    }

    @Test
    fun `schedule creates PendingIntent with correct action`() {
        WidgetAlarmScheduler.schedule(context)

        val scheduledAlarm = shadowAlarmManager.nextScheduledAlarm
        assertNotNull(scheduledAlarm)

        val shadowPendingIntent = Shadows.shadowOf(scheduledAlarm!!.operation)
        assertTrue(shadowPendingIntent.isBroadcastIntent)

        val savedIntent = shadowPendingIntent.savedIntent
        assertEquals(WidgetAlarmReceiver.ACTION_ALARM_UPDATE, savedIntent.action)
        assertEquals(context.packageName, savedIntent.`package`)
    }

    @Test
    fun `schedule can be called multiple times safely`() {
        // Should not crash or create multiple alarms
        WidgetAlarmScheduler.schedule(context)
        WidgetAlarmScheduler.schedule(context)
        WidgetAlarmScheduler.schedule(context)

        // Should still have only one alarm (updated, not duplicated)
        val alarms = shadowAlarmManager.scheduledAlarms
        assertEquals(1, alarms.size)
    }

    @Test
    fun `cancel removes the scheduled alarm`() {
        WidgetAlarmScheduler.schedule(context)
        assertNotNull(shadowAlarmManager.nextScheduledAlarm)

        WidgetAlarmScheduler.cancel(context)

        assertNull("Alarm should be cancelled", shadowAlarmManager.nextScheduledAlarm)
    }

    @Test
    fun `cancel is safe when no alarm scheduled`() {
        // Should not crash
        WidgetAlarmScheduler.cancel(context)

        assertNull(shadowAlarmManager.nextScheduledAlarm)
    }

    @Test
    fun `schedule sets trigger time in the future`() {
        WidgetAlarmScheduler.schedule(context)

        val scheduledAlarm = shadowAlarmManager.nextScheduledAlarm
        assertNotNull(scheduledAlarm)

        // Trigger time should be approximately 15 minutes from now (in elapsed realtime)
        val expectedMinTrigger = android.os.SystemClock.elapsedRealtime()
        val expectedMaxTrigger = expectedMinTrigger + AlarmManager.INTERVAL_FIFTEEN_MINUTES + 1000

        assertTrue("Trigger time should be in the future",
            scheduledAlarm!!.triggerAtTime >= expectedMinTrigger)
        assertTrue("Trigger time should be within 15 minutes",
            scheduledAlarm.triggerAtTime <= expectedMaxTrigger)
    }

    @Test
    fun `PendingIntent uses FLAG_IMMUTABLE`() {
        WidgetAlarmScheduler.schedule(context)

        val scheduledAlarm = shadowAlarmManager.nextScheduledAlarm
        assertNotNull(scheduledAlarm)

        val shadowPendingIntent = Shadows.shadowOf(scheduledAlarm!!.operation)
        val flags = shadowPendingIntent.flags

        // FLAG_IMMUTABLE should be set for security
        assertTrue("FLAG_IMMUTABLE should be set",
            (flags and PendingIntent.FLAG_IMMUTABLE) != 0)
    }
}
