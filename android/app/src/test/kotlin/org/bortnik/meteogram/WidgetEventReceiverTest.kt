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
 * Unit tests for WidgetEventReceiver.
 *
 * Tests verify that the receiver handles system broadcasts correctly.
 * Note: Actual widget update is not tested as it requires AppWidgetManager,
 * which is not available in unit tests.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class WidgetEventReceiverTest {

    private lateinit var context: Context
    private lateinit var receiver: WidgetEventReceiver

    @Before
    fun setup() {
        context = RuntimeEnvironment.getApplication()
        receiver = WidgetEventReceiver()
    }

    @Test
    fun `onReceive handles ACTION_LOCALE_CHANGED without crashing`() {
        val intent = Intent(Intent.ACTION_LOCALE_CHANGED)

        // Should not throw
        receiver.onReceive(context, intent)
    }

    @Test
    fun `onReceive handles ACTION_TIMEZONE_CHANGED without crashing`() {
        val intent = Intent(Intent.ACTION_TIMEZONE_CHANGED)

        // Should not throw
        receiver.onReceive(context, intent)
    }

    @Test
    fun `onReceive handles unknown action without crashing`() {
        val intent = Intent("com.example.UNKNOWN_ACTION")

        // Should not throw - unknown actions are silently ignored
        receiver.onReceive(context, intent)
    }

    @Test
    fun `onReceive handles null action without crashing`() {
        val intent = Intent()

        // Should not throw
        receiver.onReceive(context, intent)
    }

    @Test
    fun `receiver can be instantiated`() {
        val newReceiver = WidgetEventReceiver()
        assertNotNull(newReceiver)
    }

    // ==================== Intent Action Constants ====================

    @Test
    fun `ACTION_LOCALE_CHANGED is correct system constant`() {
        assertEquals("android.intent.action.LOCALE_CHANGED", Intent.ACTION_LOCALE_CHANGED)
    }

    @Test
    fun `ACTION_TIMEZONE_CHANGED is correct system constant`() {
        assertEquals("android.intent.action.TIMEZONE_CHANGED", Intent.ACTION_TIMEZONE_CHANGED)
    }
}
