
plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.android")      // replaces "kotlin-android"
  id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

android {
  namespace = "com.noctisapp.app"
  compileSdk = 36

  defaultConfig {
    applicationId = "com.noctisapp.app"
    minSdk = flutter.minSdkVersion
    targetSdk = 36
    versionCode = flutter.versionCode
    versionName = flutter.versionName
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
    isCoreLibraryDesugaringEnabled = true
  }
  kotlinOptions { jvmTarget = "17" }

  signingConfigs {
    create("release") {
      val propsFile = rootProject.file("android/key.properties")
      val p = Properties()
      if (propsFile.exists()) {
        // Use Kotlin's inputStream() extension so the Kotlin DSL resolves the type correctly
        propsFile.inputStream().use { p.load(it) }
      } else {
        val envStore = System.getenv("KEYSTORE_PATH")
        if (!envStore.isNullOrBlank()) {
          p.setProperty("storeFile", envStore)
          p.setProperty("storePassword", System.getenv("KEYSTORE_PASSWORD") ?: "")
          p.setProperty("keyAlias", System.getenv("KEY_ALIAS") ?: "")
          p.setProperty("keyPassword", System.getenv("KEY_PASSWORD") ?: "")
        }
      }

      val storeFileProp = p.getProperty("storeFile")
      if (!storeFileProp.isNullOrBlank()) {
        storeFile = file(storeFileProp)
        storePassword = p.getProperty("storePassword")
        keyAlias = p.getProperty("keyAlias")
        keyPassword = p.getProperty("keyPassword")
      } else {
        project.logger.warn("Release signing config not found. CI should provide android/key.properties or KEYSTORE_* env vars.")
      }
    }
    getByName("debug") { /* default */ }
  }

  buildTypes {
    getByName("debug") {
      isDebuggable = true
      isMinifyEnabled = false
      isShrinkResources = false
      signingConfig = signingConfigs.getByName("debug")
    }
    getByName("release") {
      isDebuggable = false
      val releaseConfig = signingConfigs.findByName("release")
      if (releaseConfig != null && releaseConfig.storeFile != null) {
        signingConfig = releaseConfig
      } else {
        signingConfig = signingConfigs.getByName("debug")
        project.logger.warn("Building release APK using debug signing because release keystore was not configured. Do NOT use this for Play Store uploads.")
      }
      isMinifyEnabled = true
      isShrinkResources = true
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
      ndk { debugSymbolLevel = "NONE" }
    }
  }

  lint {
    checkReleaseBuilds = true
    abortOnError = true
    warningsAsErrors = true
  }

  packaging {
    resources {
      excludes += setOf("META-INF/LICENSE*", "META-INF/NOTICE*")
    }
  }
}

dependencies {
  coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
  // other deps…
}

flutter { source = "../.." }
