# Vidya TrackIt (Flutter demo)

Live bus-tracking demo app for Vidya Engineering College.
Login -> Dashboard -> Live map with an auto-moving (fake GPS) bus -> proximity alarm.

> 100%% demo: no real GPS, servers, or accounts. Everything is simulated on-device.

## Build the APK on GitHub (no local setup needed)

1. Create a new GitHub repository.
2. Upload the **contents** of this folder to the repo root, so the repo looks like:
   - `pubspec.yaml`
   - `lib/main.dart`
   - `.github/workflows/build-apk.yml`
3. Push to the `main` (or `master`) branch. The workflow runs automatically.
   (Or go to the **Actions** tab -> *Build Vidya TrackIt APK* -> **Run workflow**.)
4. When the run finishes (green check), open it and download the
   **vidya-trackit-apk** artifact at the bottom. Inside is `app-release.apk`.
5. Copy the APK to an Android phone, allow "install from unknown sources", and install.

## Demo login

- Username: `user`
- Password: `password`
- (Any input works — just tap **Login**.)

## What to show

- Dashboard auto-detects the student's route (Route 12).
- The map opens and the bus starts moving on its own, looping the route with live speed / ETA.
- Pick a distance (1 km / 500 m / 250 m / At stop) and tap **Set Proximity Alarm**.
- When the bus reaches that range of Punkunnam, a full-screen alarm fires with vibration.
