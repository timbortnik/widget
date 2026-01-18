package org.bortnik.meteogram

import android.content.Context
import android.os.Build
import android.util.Log

/**
 * Extracts Material You (dynamic) colors from the system and detects changes.
 * Used to trigger widget re-render when user changes wallpaper/theme colors.
 *
 * Color palettes (Android 12+):
 * - system_accent1_*: Primary accent color
 * - system_accent2_*: Secondary accent color
 * - system_accent3_*: Tertiary accent color
 * - system_neutral1_*: Neutral surface colors
 * - system_neutral2_*: Neutral variant colors
 *
 * Tone values: 0 (white) to 1000 (black)
 */
object MaterialYouColorExtractor {
    private const val TAG = "MaterialYouColors"

    // Keys for Flutter SharedPreferences
    private const val KEY_LIGHT_PRIMARY = "material_you_light_primary"
    private const val KEY_LIGHT_ON_PRIMARY_CONTAINER = "material_you_light_on_primary_container"
    private const val KEY_LIGHT_TERTIARY = "material_you_light_tertiary"
    private const val KEY_LIGHT_SURFACE = "material_you_light_surface"
    private const val KEY_LIGHT_SURFACE_CONTAINER = "material_you_light_surface_container"
    private const val KEY_LIGHT_SURFACE_CONTAINER_HIGH = "material_you_light_surface_container_high"
    private const val KEY_LIGHT_ON_SURFACE = "material_you_light_on_surface"

    private const val KEY_DARK_PRIMARY = "material_you_dark_primary"
    private const val KEY_DARK_ON_PRIMARY_CONTAINER = "material_you_dark_on_primary_container"
    private const val KEY_DARK_TERTIARY = "material_you_dark_tertiary"
    private const val KEY_DARK_SURFACE = "material_you_dark_surface"
    private const val KEY_DARK_SURFACE_CONTAINER = "material_you_dark_surface_container"
    private const val KEY_DARK_SURFACE_CONTAINER_HIGH = "material_you_dark_surface_container_high"
    private const val KEY_DARK_ON_SURFACE = "material_you_dark_on_surface"

    private const val KEY_COLORS_HASH = "material_you_colors_hash"

    // Legacy keys for backward compatibility
    private const val KEY_LIGHT_TEMP = "material_you_light_temp"
    private const val KEY_LIGHT_TIME = "material_you_light_time"
    private const val KEY_DARK_TEMP = "material_you_dark_temp"
    private const val KEY_DARK_TIME = "material_you_dark_time"

    /**
     * Check if Material You colors are available on this device.
     */
    fun isAvailable(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

    /**
     * Extract current Material You colors, compare with cached values, and save if changed.
     *
     * @return true if colors changed and were saved (re-render needed), false otherwise
     */
    fun updateColorsIfChanged(context: Context): Boolean {
        if (!isAvailable()) {
            return false
        }

        try {
            // Extract accent colors
            val lightPrimary = context.getColor(android.R.color.system_accent1_800)  // Darker for light bg
            val lightOnPrimaryContainer = context.getColor(android.R.color.system_accent1_900)
            val lightTertiary = context.getColor(android.R.color.system_accent3_800)  // Darker for light bg
            val darkPrimary = context.getColor(android.R.color.system_accent1_300)  // More saturated
            val darkOnPrimaryContainer = context.getColor(android.R.color.system_accent1_100)
            val darkTertiary = context.getColor(android.R.color.system_accent3_300)  // More saturated

            // Extract surface colors from neutral palette
            // Light: lower tone numbers = lighter colors
            val lightSurface = context.getColor(android.R.color.system_neutral1_10)
            val lightSurfaceContainer = context.getColor(android.R.color.system_neutral1_100)
            val lightSurfaceContainerHigh = context.getColor(android.R.color.system_neutral1_200)
            val lightOnSurface = context.getColor(android.R.color.system_neutral1_900)

            // Dark: higher tone numbers = darker colors
            val darkSurface = context.getColor(android.R.color.system_neutral1_900)
            val darkSurfaceContainer = context.getColor(android.R.color.system_neutral1_800)
            val darkSurfaceContainerHigh = context.getColor(android.R.color.system_neutral1_700)
            val darkOnSurface = context.getColor(android.R.color.system_neutral1_100)

            // Hash all colors to detect changes
            val allColors = arrayOf(
                lightPrimary, lightOnPrimaryContainer, lightTertiary,
                lightSurface, lightSurfaceContainer, lightSurfaceContainerHigh, lightOnSurface,
                darkPrimary, darkOnPrimaryContainer, darkTertiary,
                darkSurface, darkSurfaceContainer, darkSurfaceContainerHigh, darkOnSurface
            )
            val newHash = allColors.contentHashCode()

            val prefs = context.getSharedPreferences(WidgetUtils.PREFS_NAME, Context.MODE_PRIVATE)
            val oldHash = prefs.getInt(KEY_COLORS_HASH, 0)

            if (newHash != oldHash) {
                Log.d(TAG, "Material You colors changed (hash: $oldHash -> $newHash)")
                Log.d(TAG, "Dark surface: ${Integer.toHexString(darkSurface)}, container: ${Integer.toHexString(darkSurfaceContainer)}, high: ${Integer.toHexString(darkSurfaceContainerHigh)}")

                // Save all colors for Flutter to read
                prefs.edit()
                    // Light theme
                    .putInt(KEY_LIGHT_PRIMARY, lightPrimary)
                    .putInt(KEY_LIGHT_ON_PRIMARY_CONTAINER, lightOnPrimaryContainer)
                    .putInt(KEY_LIGHT_TERTIARY, lightTertiary)
                    .putInt(KEY_LIGHT_SURFACE, lightSurface)
                    .putInt(KEY_LIGHT_SURFACE_CONTAINER, lightSurfaceContainer)
                    .putInt(KEY_LIGHT_SURFACE_CONTAINER_HIGH, lightSurfaceContainerHigh)
                    .putInt(KEY_LIGHT_ON_SURFACE, lightOnSurface)
                    // Dark theme
                    .putInt(KEY_DARK_PRIMARY, darkPrimary)
                    .putInt(KEY_DARK_ON_PRIMARY_CONTAINER, darkOnPrimaryContainer)
                    .putInt(KEY_DARK_TERTIARY, darkTertiary)
                    .putInt(KEY_DARK_SURFACE, darkSurface)
                    .putInt(KEY_DARK_SURFACE_CONTAINER, darkSurfaceContainer)
                    .putInt(KEY_DARK_SURFACE_CONTAINER_HIGH, darkSurfaceContainerHigh)
                    .putInt(KEY_DARK_ON_SURFACE, darkOnSurface)
                    // Hash
                    .putInt(KEY_COLORS_HASH, newHash)
                    // Legacy keys for backward compatibility
                    .putInt(KEY_LIGHT_TEMP, lightPrimary)
                    .putInt(KEY_LIGHT_TIME, lightTertiary)
                    .putInt(KEY_DARK_TEMP, darkPrimary)
                    .putInt(KEY_DARK_TIME, darkTertiary)
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
