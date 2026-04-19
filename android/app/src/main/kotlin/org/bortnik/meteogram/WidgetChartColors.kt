package org.bortnik.meteogram

import android.content.Context
import android.os.Build
import android.util.Log

/**
 * Resolves chart colors for widget rendering, applying Material You
 * dynamic colors when available (Android 12+).
 */
object WidgetChartColors {
    private const val TAG = "WidgetChartColors"

    /**
     * Get chart colors for a theme, applying Material You colors if available.
     */
    fun get(context: Context, isLight: Boolean): SvgChartColors {
        val baseColors = if (isLight) SvgChartColors.light else SvgChartColors.dark

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return baseColors
        }

        val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)

        val tempColorKey = if (isLight) "material_you_light_on_primary_container" else "material_you_dark_primary"
        val timeColorKey = if (isLight) "material_you_light_tertiary" else "material_you_dark_tertiary"

        val tempColor = prefs.getInt(tempColorKey, 0)
        val timeColor = prefs.getInt(timeColorKey, 0)

        if (tempColor == 0 || timeColor == 0) {
            Log.d(TAG, "Material You colors not available, using defaults")
            return baseColors
        }

        Log.d(TAG, "Applying Material You colors: temp=${Integer.toHexString(tempColor)}, time=${Integer.toHexString(timeColor)}")
        return baseColors.withDynamicColors(
            temperatureLine = SvgColor.fromArgb(tempColor),
            timeLabel = SvgColor.fromArgb(timeColor)
        )
    }
}
