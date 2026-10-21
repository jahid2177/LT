# Android TV / Android Mobile — SharedPreferences startup error fix

## Error confirmed by screenshot

`PlatformException ... java.lang.NoSuchMethodError: ... SharedPreferencesApiRegistrar.getAll(...Continuation...)`

This matches the `shared_preferences_android` 2.5.0 Pigeon JNI / Android R8 issue introduced in October 2026. The screen error may show **Bundled channels failed**, but the JSON is **not** the cause: saving/restoring the playlist triggers the preference plugin bug.

## Changes

1. `pubspec.yaml`: exact `shared_preferences_android: 2.4.28`, so `flutter pub get` cannot silently choose 2.5.0; app version bumped.
2. `android/app/proguard-rules.pro`: six targeted Kotlin JNI preserve rules while keeping AndroidX WindowManager optional OEM `-dontwarn` rules.
3. GitHub Actions validates the **resolved** `pubspec.lock` package version before building.
4. The GitHub JSON live primary source and 2-minute automatic refresh are unchanged.

## Build steps

1. Unzip this **full** project and upload its files to the **same repository root** (including `.github`). Do not upload the outer folder as an extra directory.
2. GitHub → Actions → **Android TV APK** → Run workflow.
3. In the action log, confirm **Verify release-only SharedPreferences JNI regression workaround** reports `2.4.28`.
4. After success, download artifact **Live-TV-Remote-AndroidTV-arm64** → extract → install `app-release.apk` on the TV.
5. If you have an existing copy installed, first **try installing as an update** to preserve favorites and cached settings. If the Android installer reports a different signing certificate, uninstall the old APK and reinstall. **Uninstalling deletes app preferences.**
6. Open: the **channel guide** should display first. Choose a channel and press OK. Test again after waiting at least 2 minutes, so it fetches any new links from GitHub.

### Important note about debugging

This update fixes the specific `SharedPreferencesApiRegistrar.getAll` crash shown in the image. If Android TV still **closes instantly**, there may be a second TV-specific issue. Capture a fresh TV log after this release:

```sh
adb logcat -c
adb shell monkey -p com.example.live_tv_remote 1
adb logcat -d -v time > live_tv_crash.txt
```

Or install the separate Diagnostic-debug artifact to tell whether the release-only R8 path is involved. Debug uses package `com.example.live_tv_remote.diagnostic`, so it can coexist with release.

**Not verified on physical TV:** build/TV install is required for final confirmation.

References: https://pub.dev/packages/shared_preferences_android/changelog ; https://github.com/flutter/flutter/issues/194649
