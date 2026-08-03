pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // Reads android/app/google-services.json (from the Firebase console) at
    // build time — needed for firebase_core/firebase_messaging to work at
    // all. Not applied here (apply false); actually applied per-module in
    // android/app/build.gradle.kts, same pattern as the two plugins above.
    // See PUSH_NOTIFICATIONS_SETUP.md for where that json file comes from.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
