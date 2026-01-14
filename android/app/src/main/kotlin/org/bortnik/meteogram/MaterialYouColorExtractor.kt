package org.bortnik.meteogram

import android.content.Context
import android.os.Build
import android.util.Log

/**
 * Extracts Material You (dynamic) colors from the system and detects changes.
 * Used to trigger widget re-render when user changes wallpaper/theme colors.
 */
object MaterialYouColorExtractor {
    private const val TAG = "MaterialYouColors"

    // Keys matching Flutter's background_service.dart
    private const val KEY_LIGHT_TEMP = "material_you_light_temp"
    private const val KEY_LIGHT_TIME = "material_you_light_time"
    private const val KEY_DARK_TEMP = "material_you_dark_temp"
    private const val KEY_DARK_TIME = "material_you_dark_time"
    private const val KEY_COLORS_HASH = "material_you_colors_hash"

    /**
     * Extract current Material You colors, compare with cached values, and save if changed.
     *
     * Color mapping:
     * - Temperature line: system_accent1 (primary color)
     * - Time labels: system_accent3 (tertiary color)
     * - Light theme uses _600 variants, dark theme uses _200 variants
     *
     * @return true if colors changed and were saved (re-render needed), false otherwise
     */
    fun checkAndUpdateColors(context: Context): Boolean {
        // Material You colors only available on Android 12+
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return false
        }

        try {
            // Extract current system colors
            val lightTemp = context.getColor(android.R.color.system_accent1_600)
            val lightTime = context.getColor(android.R.color.system_accent3_600)
            val darkTemp = context.getColor(android.R.color.system_accent1_200)
            val darkTime = context.getColor(android.R.color.system_accent3_200)

            // Proper hash to detect any color change (prevents collision if colors swap)
            val newHash = arrayOf(lightTemp, lightTime, darkTemp, darkTime).contentHashCode()

            val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
            val oldHash = prefs.getInt(KEY_COLORS_HASH, 0)

            if (newHash != oldHash) {
                Log.d(TAG, "Material You colors changed (hash: $oldHash -> $newHash)")
                Log.d(TAG, "Light: temp=${Integer.toHexString(lightTemp)}, time=${Integer.toHexString(lightTime)}")
                Log.d(TAG, "Dark: temp=${Integer.toHexString(darkTemp)}, time=${Integer.toHexString(darkTime)}")

                // Save new colors for Flutter to read
                prefs.edit()
                    .putInt(KEY_LIGHT_TEMP, lightTemp)
                    .putInt(KEY_LIGHT_TIME, lightTime)
                    .putInt(KEY_DARK_TEMP, darkTemp)
                    .putInt(KEY_DARK_TIME, darkTime)
                    .putInt(KEY_COLORS_HASH, newHash)
                    .commit()

                return true
            }

            return false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to extract Material You colors", e)
            return false
        }
    }
}
