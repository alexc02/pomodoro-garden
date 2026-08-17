plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pipgarden.pip_garden"

    // Compile against the same API level we target, so the compiler flags
    // behaviour changes rather than leaving them to surface at runtime.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // flutter_local_notifications needs desugaring (java.time).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.pipgarden.pip_garden"

        // Android 8.0: notification channels and the current foreground
        // service model.
        minSdk = 26

        // Play requires API 36 from 31 Aug 2026.
        targetSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // See `isCoreLibraryDesugaringEnabled` above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Used directly by LiveSessionService, so pinned here instead of relying
    // on a plugin's transitive version. 1.12+ for ServiceCompat.startForeground
    // with a service type.
    implementation("androidx.core:core-ktx:1.13.1")
}

flutter {
    source = "../.."
}
