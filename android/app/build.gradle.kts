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

        // Required by flutter_local_notifications from version 10 on: it uses
        // the java.time API, which API 26 has but which the plugin supports
        // further back by desugaring. Ticket 06 needs the plugin, so the app
        // needs this, whether or not any of our own code uses those APIs.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.pipgarden.pip_garden"

        // Android 8.0. Below this there are no notification channels and no
        // modern foreground-service model, both of which ticket 08 needs to
        // keep a running session visible.
        minSdk = 26

        // Android 16. Play requires new apps to target API 35 today and API 36
        // from 31 Aug 2026; this app ships after that date, so target 36 now
        // rather than take the bump as a release blocker later.
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

    // Ticket 08's foreground service. Declared rather than inherited from a
    // plugin's own dependencies: `NotificationCompat` and `ServiceCompat` are
    // this app's own code's, and a version arriving transitively is a version
    // that changes when an unrelated plugin is upgraded.
    //
    // `ServiceCompat.startForeground` with a service type needs 1.12 or later —
    // it is what keeps Android 14's mandatory type out of a version check in
    // `LiveSessionService`.
    implementation("androidx.core:core-ktx:1.13.1")
}

flutter {
    source = "../.."
}
