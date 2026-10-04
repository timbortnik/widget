# Flutter: no blanket io.flutter keeps. The engine marks its JNI entry points @Keep
# and Flutter's Gradle plugin adds flutter_proguard_rules.pro — same as a stock app.

# Play Core library (deferred components) - not used but referenced by Flutter
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# AndroidSVG library: no keep needed — called directly; its reflection only targets
# framework classes (Canvas.save(int), SAXParserFactory), and enums are kept below.
-dontwarn com.caverock.androidsvg.**

# Keep widget provider and related classes
-keep class org.bortnik.meteogram.MeteogramWidgetProvider { *; }
-keep class org.bortnik.meteogram.WidgetEventReceiver { *; }
-keep class org.bortnik.meteogram.WeatherUpdateWorker { *; }
-keep class org.bortnik.meteogram.MeteogramApplication { *; }

# Kotlin serialization (if used)
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# OkHttp / HTTP client (used by Flutter http package)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# Gson (if used for JSON parsing)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# General Android
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
