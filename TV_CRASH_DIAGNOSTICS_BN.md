# Live TV Remote — Android TV launch crash mitigation (21 Oct 2026)

## Reported symptom

The `app-release.apk` builds and installs on TV, but the app closes as soon as it opens.
**No device-side crash stack trace has been supplied yet.** This revision addresses
potential startup hazards; it is NOT a verified fix for the unknown device crash.

## Source-code findings and changes

- Previously, `main()` awaited Android `SystemChrome` calls before `runApp`.
  The first UI frame now renders first; immersive mode is a best-effort task.
  Landscape is already specified in the Android manifest.
- The first launch immediately called `_tune(0)` on bundled 513 channels and,
  after GitHub refresh, could call `_tune()` again. This could initiate two
  native decoders on a low-resource TV. Startup now opens the channel guide,
  WITHOUT allocating a video decoder. Press remote **OK** to play one channel.
- Online refresh preserves active playback when the same stream remains in
  the playlist; it no longer starts a second player at first launch.
- Decoder create/init/dispose operations are serialized in a task queue.
  A stale tune request is ignored, and a 20-second initialize timeout reports
  an error instead of spinning indefinitely (native crashes cannot be caught
  by Dart exception handling).
- A diagnostic Android APK is produced by the workflow using a different
  application ID: `com.example.live_tv_remote.diagnostic`. This build can be
  installed alongside the release APK and helps distinguish release/R8
  problems from runtime/player problems.

## TV verification sequence

1. Build using GitHub Actions > Android TV APK > Run workflow.
2. Install **release** APK and open it. A channel guide should appear with a
   message to use remote Up/Down and OK; no streaming before OK.
3. Press OK on one known working/authorized HLS channel.
4. Verify CH+/CH-, D-pad and volume; launch the app a second time.
5. If release still crashes at open, install the **Diagnostic-debug** APK
   alongside it and see whether that version opens.
6. Capture **logcat** after launch if either APK crashes (see below).

## Crash log commands (Windows PC, ADB paired with TV)

Enable TV Developer options and (wireless) debugging, pair ADB according to
that model's instructions. With TV connected to the PC:

```powershell
adb devices
adb logcat -c
adb shell am force-stop com.example.live_tv_remote
adb shell monkey -p com.example.live_tv_remote -c android.intent.category.LAUNCHER 1
adb logcat -d -v time > live_tv_crash.txt
```

If testing the diagnostic APK, replace the package in both commands with
`com.example.live_tv_remote.diagnostic`.

The relevant messages usually include `FATAL EXCEPTION`, `AndroidRuntime`,
`Fatal signal`, `flutter`, `MediaCodec`, or `ExoPlayer` near the crash.
If a TV provides a crash-report export, it is also acceptable.

## Important limitations

- R8/ProGuard rules from the prior build are preserved. A successful build
  is not proof that the TV supports all stream codecs.
- Some JSON URLs have expired tokens; these may fail during playback.
- Flutter SDK / Android SDK are unavailable here. No APK or on-device runtime
  tests were performed. Only source and structural verification are possible.
