# Android Gradle setup (Firebase + background location)

These are the native tweaks CI (or a local `flutter build apk`) needs after
`flutter create` scaffolds the `android/` folder. The GitHub Actions workflow
copies `AndroidManifest.xml` in automatically; the Gradle bits below you apply
once if you build a Firebase-connected release yourself.

## 1. Google Services plugin (only needed once you add google-services.json)

**android/settings.gradle** - add to the `plugins { }` block:
```groovy
id "com.google.gms.google-services" version "4.4.2" apply false
```

**android/app/build.gradle** - add at the top `plugins { }` block:
```groovy
id "com.google.gms.google-services"
```

## 2. Min SDK / desugaring

In **android/app/build.gradle**, inside `android { defaultConfig { } }`:
```groovy
minSdkVersion 23          // flutter_local_notifications + geolocator need >=21; 23 is safe
targetSdkVersion 34
multiDexEnabled true
```

`flutter_local_notifications` needs core library desugaring:
```groovy
android {
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.2'
}
```

## 3. google-services.json

Place your downloaded `google-services.json` at **android/app/google-services.json**.
Without it the app still compiles and the demo UI + OSM map run, but Firebase
init fails at runtime (Realtime Database + FCM stay offline). Keep it out of a
public repo; in CI inject it from a secret.

## 4. Alarm sound (optional)

Drop an `alarm.mp3`/`alarm.wav` into **android/app/src/main/res/raw/alarm.<ext>**
to match the `RawResourceAndroidNotificationSound('alarm')` used by the alarm
channel. If you skip it, remove that sound argument in
`lib/services/notifications_service.dart` so the default sound is used.
