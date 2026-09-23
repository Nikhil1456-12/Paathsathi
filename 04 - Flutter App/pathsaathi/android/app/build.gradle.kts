plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pathsaathi.pathsaathi"
    // compileSdk 36 required by sqflite_android 2.4.3 (VERSION_CODES.BAKLAVA) and onnxruntime
    compileSdk = 36
    // Pin NDK version required by whisper.cpp and onnxruntime native .so builds
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.pathsaathi.pathsaathi"
        // minSdk 24 required by onnxruntime 1.4.1 and whisper_flutter_new
        // Android 7.0+ covers 99%+ of active devices
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // NOTE: ABI restriction is done at build time via `--split-per-abi`
        // (produces a dedicated arm64-v8a APK). An `ndk.abiFilters` block here
        // conflicts with `--split-per-abi`, so it is intentionally omitted.
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // ── APK SIZE REDUCTION ──────────────────────────────────────────
            // R8 code shrinking + resource shrinking strips unused Dart-bridge
            // and plugin code/resources from the release APK.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    // NOTE: A single lean APK per ABI is achieved via `ndk.abiFilters` above
    // (restricted to arm64-v8a) plus Flutter's `--split-per-abi` build flag,
    // rather than a Gradle `splits {}` block (which conflicts with the ABI
    // filter Flutter injects). Combined with the on-demand model-download
    // strategy, the base install stays small and heavy quantized models are
    // fetched later on WiFi.
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
