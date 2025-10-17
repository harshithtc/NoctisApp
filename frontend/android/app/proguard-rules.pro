## Keep Flutter and Kotlin runtime used by the app and common plugins

# Keep Flutter engine and plugin entry points
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Kotlin runtime
-keep class kotlin.** { *; }
-dontwarn kotlin.**
-keep class kotlinx.** { *; }

# Strip Android log calls to reduce leak surface in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# OkHttp / Okio / Gson - protect reflection usage used by some plugins
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory

# Keep common runtime attributes used by reflection-based serializers
-keepattributes Signature, RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
