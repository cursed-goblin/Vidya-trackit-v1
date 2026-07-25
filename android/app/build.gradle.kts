
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// START: FlutterFire Configuration
//
// google-services.json holds the Firebase Cloud Messaging config. It is
// gitignored (it is per-project, and forks must not inherit ours), so it is
// absent on CI and on a fresh clone. Applying the plugin unconditionally makes
// :app:processDebugGoogleServices fail the whole build with
// "File google-services.json is missing".
//
// The app is built to tolerate a missing Firebase: main() wraps
// Firebase.initializeApp() in a try/catch, gFirebaseReady stays false, and the
// proximity alarm falls back to a local notification while the app is open.
// Only background push needs FCM.
//
// So: apply the plugin only when the file is actually there. Run
// `flutterfire configure` and it starts working with no edit to this file.
val googleServicesJson =
    listOf(
        "google-services.json",
        "src/debug/google-services.json",
        "src/release/google-services.json",
    ).any { file(it).exists() }

if (googleServicesJson) {
    apply(plugin = "com.google.gms.google-services")
    logger.lifecycle("google-services.json found - FCM push enabled")
} else {
    logger.lifecycle(
        "google-services.json not found - building without FCM. " +
            "Push alarms stay disabled; run `flutterfire configure` to enable them.",
    )
}
// END: FlutterFire Configuration

android {
    namespace = "com.vidya.vidya_trackit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.vidya.vidya_trackit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
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

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
