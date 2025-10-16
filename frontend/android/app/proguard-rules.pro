# Keep Flutter and Kotlin
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# Strip Android log calls in release to avoid leaking data
-assumenosideeffects class android.util.Log {
  public static *** d(...);
  public static *** v(...);
  public static *** i(...);
  public static *** w(...);
  public static *** println(...);
}

# If plugins use OkHttp/Gson via reflection
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keepattributes Signature, RuntimeVisibleAnnotations, RuntimeVisibleParameterAnnotations
