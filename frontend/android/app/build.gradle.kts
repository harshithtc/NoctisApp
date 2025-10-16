android {
  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
    isCoreLibraryDesugaringEnabled = true
  }
  kotlinOptions { jvmTarget = "17" }

  defaultConfig {
    applicationId = "com.noctisapp.app"
    minSdk = flutter.minSdkVersion
    targetSdk = flutter.targetSdkVersion
    versionCode = flutter.versionCode
    versionName = flutter.versionName
  }

  signingConfigs {
    create("release") {
      val propsFile = rootProject.file("android/key.properties")
      if (!propsFile.exists()) error("android/key.properties missing: aborting release build")
      val p = java.util.Properties().apply { load(java.io.FileInputStream(propsFile)) }
      storeFile = file(p["storeFile"] as String)
      storePassword = p["storePassword"] as String
      keyAlias = p["keyAlias"] as String
      keyPassword = p["keyPassword"] as String
    }
    getByName("debug") { /* default */ }
  }

  buildTypes {
    getByName("debug") {
      isDebuggable = true
      signingConfig = signingConfigs.getByName("debug")
      isMinifyEnabled = false
      isShrinkResources = false
    }
    getByName("release") {
      isDebuggable = false
      signingConfig = signingConfigs.getByName("release")
      isMinifyEnabled = true
      isShrinkResources = true
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
      ndk { debugSymbolLevel = "none" }
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
