pluginManagement {
  val flutterSdkPath = run {
    val properties = java.util.Properties()
    val localPropsFile = file("local.properties")
    if (localPropsFile.exists()) {
      localPropsFile.inputStream().use { properties.load(it) }
      val sdkFromProps = properties.getProperty("flutter.sdk")
      if (!sdkFromProps.isNullOrBlank()) return@run sdkFromProps
    }
    val envSdk = System.getenv("FLUTTER_ROOT") ?: System.getenv("FLUTTER_SDK")
    if (!envSdk.isNullOrBlank()) return@run envSdk
    logger.warn("local.properties missing and FLUTTER_ROOT/FLUTTER_SDK not set; skipping includeBuild for flutter_tools.")
    ""
  }

  if (flutterSdkPath.isNotEmpty()) {
    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
  }

  repositories {
    google()
    mavenCentral()
    gradlePluginPortal()
  }
}

plugins {
  id("com.android.application") version "8.8.0" apply false
  id("com.android.library") version "8.8.0" apply false
  id("org.jetbrains.kotlin.android") version "2.2.0" apply false
  id("dev.flutter.flutter-plugin-loader") version "1.0.0"
}


include(":app")
