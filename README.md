# Live TV Remote — Flutter + Android TV

Android TV / Google TV-এর জন্য **remote-first IPTV Live TV app**, written in Flutter (Dart) + a small Kotlin Android remote-key bridge.

> ⚠️ **What this project is / is not**
> This app plays **user-supplied, authorized network TV streams** from M3U playlists. It is **not** an Android hardware DVB-T/C/S tuner application and it does not read proprietary built-in TV broadcast channel lists. Hardware tuner access requires an OEM tuner/TV Input Framework integration and appropriate permissions. It contains **no copyrighted/pirated channel list**.

## Features

- Android TV / Google TV leanback launcher banner + standard launcher
- Full-screen, landscape, immersive player (video_player / Android ExoPlayer backend)
- M3U channels using **HTTP/HTTPS HLS `.m3u8`**, DASH/MP4 when supported by the underlying player
- Remote hardware **CH+ / CH−** (Android key codes 166 and 167)
- D-pad **UP/DOWN** switches channels when guide is hidden, navigates the guide when open
- D-pad **OK/Select** opens channel guide / tunes selected channel
- D-pad **LEFT/RIGHT**, MENU / GUIDE and BACK for navigation
- Remote numbers **1–9, 0** for direct channel number entry
- **VOLUME+ / VOLUME−** delegated to Android TV's normal system/media-volume control (not emulated in Flutter)
- M3U import from URL, Android file picker (where provided), or pasted M3U text
- Favorite/unfavorite, favorites-only guide, last channel on relaunch
- Stream loading/error and retry UI
- Demo M3U with sample test videos for checking the playback pipeline (these are **not live TV channels**)
- GitHub Actions: static analysis, unit tests, build an **ARM64 release APK**, upload as downloadable artifact

## Remote controls

| Remote key | Playback screen | Channel guide |
|---|---|---|
| CH+ / CH− | Next / previous channel | Next / previous channel (guide closes) |
| D-pad UP / DOWN | Previous / next channel | Move highlight |
| D-pad LEFT | Open guide | Close guide |
| D-pad RIGHT | Show channel info | Close guide |
| OK / SELECT / Enter | Open guide | Tune highlighted channel |
| GUIDE / MENU | Open guide | Keep guide open |
| BACK / Esc | Hide info / open guide | Close guide |
| 0–9 | Direct channel number (after ~1 second) | Direct channel number |
| Volume + / − | Default Android TV volume behavior | Default Android TV volume behavior |
| F (external keyboard) | Favorite/unfavorite current channel | Favorite/unfavorite current channel |
| M (external keyboard) | Manage playlists | Manage playlists |

> Physical TV remotes differ: **some remotes do not send channel keys to third-party apps**, and others control TV/AV receiver volume directly over IR/HDMI-CEC. On such devices, Android apps cannot override those hardware events. The D-pad always offers an app-level alternative.

## Build on GitHub (no local Android SDK needed)

1. Create a **new empty GitHub repository** (e.g. `Live-TV-Remote`).
2. **Extract the ZIP**, then upload the **contents** (including `.github/` and `android/`) to the root of the GitHub repository. Do not upload only the ZIP if you want Actions to build it.
3. Open **Actions → Android TV APK → Run workflow**; alternatively push to `main`.
4. After a successful run, download **Live-TV-Remote-AndroidTV-arm64** under **Artifacts**. Inside is `app-release.apk`.
5. Copy APK to TV (USB/ADB) and sideload. Allow installing from the relevant source if prompted.

This GitHub-ready repository stores the custom Android TV source and configuration, while letting Flutter generate missing standard platform boilerplate (including the Gradle wrapper JAR) on first build. It avoids bundling SDK-generated binary files in this ZIP.

### Local build (Flutter SDK installed)

```sh
flutter create --platforms=android --project-name=live_tv_remote --org=com.example --no-pub .
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

APK path: `build/app/outputs/flutter-apk/app-release.apk`.

**Requirements:** recent Flutter stable supporting Dart 3.12+, JDK 17 and an installed Android SDK. CI sets up Flutter and Java. CI uses the default debug keystore to sign a release-mode sideload APK; use your own secure signing key for Play Store deployment.

## Load TV channels

1. Start app; choose **Add my M3U channels** (the demo button only plays sample videos).
2. Paste your IPTV provider's **playlist URL** (`https://.../playlist.m3u`) and select **Load from URL**. Alternatively, load a local `.m3u` file or paste complete M3U text.
3. Press **OK** to open the channel guide, use **D-pad UP/DOWN + OK**, or hardware **CH+ / CH−** to switch.
4. Use the favorites button in the info overlay (or keyboard `F`) to save favorites.

Minimal supported M3U example:

```m3u
#EXTM3U
#EXTINF:-1 tvg-id="news" group-title="News" tvg-logo="",My Licensed News Channel
https://your-authorized-server.example/live/news.m3u8
#EXTINF:-1 tvg-id="sport" group-title="Sports",My Licensed Sports Channel
https://your-authorized-server.example/live/sports.m3u8
```

Replace example domains with **streams you have permission to watch**. M3U lists are cached locally for next launch; playlists fetched from URL are *not* automatically refreshed yet.

### Supported / not yet supported

| Feature | State |
|---|---|
| HLS network playback | Implemented; stream/provider-dependent |
| URL / local M3U / pasted text | Implemented |
| DVB-T/C/S, antenna, cable physical tuner | Not implemented; requires platform/vendor integration |
| DRM/Widevine login, Xtream APIs, proprietary encrypted channel feeds | Not implemented |
| XMLTV EPG and catch-up TV | Not implemented |
| Separate HDMI/CEC or TV volume override | Not possible generically; controlled by device |
| Automatic URL-token refresh and provider login | Not implemented |
| Full Play Store publication setup and release keystore | Not included |

## Project structure

```text
live_tv_remote/
├── lib/
│   ├── main.dart                          # MaterialApp / fullscreen setup
│   ├── models/channel.dart                # TV channel model
│   ├── services/m3u_parser.dart           # Pure Dart M3U parser + index wrap
│   ├── services/playlist_repository.dart  # Persistence + HTTP M3U fetch
│   └── screens/
│       ├── live_tv_screen.dart            # Player + guide + remote UI
│       └── playlist_dialog.dart           # URL/file/text playlist input
├── assets/demo_playlist.m3u
├── test/widget_test.dart                  # M3U & remote channel tests
├── android/
│   ├── app/src/main/AndroidManifest.xml   # TV launchers + permissions
│   ├── app/src/main/kotlin/.../MainActivity.kt # CH+/- native bridge
│   └── app/src/main/res/                 # Launcher icon + TV banner
├── .github/workflows/android-tv-apk.yml
└── pubspec.yaml
```

## Why Volume Up/Down needs no custom Flutter code

Android's `KEYCODE_VOLUME_UP` / `KEYCODE_VOLUME_DOWN` are **left unconsumed**; `MainActivity` uses the audio stream `STREAM_MUSIC` as the volume-control stream. This is closest to a normal Android TV player's behavior. If volume keys are intercepted by the TV itself, only the firmware/IR/HDMI-CEC layer controls the external audio device.

## Privacy and safety

- No login, analytics, tracking, backend, or bundled broadcast subscriptions.
- Playlists and favorites are stored **locally, unencrypted** in app preferences. Avoid importing permanent secret tokens on shared TVs; some IPTV URLs embed credentials.
- Cleartext HTTP is enabled in the Android manifest to support authorized LAN IPTV streams; **prefer HTTPS**. On untrusted networks, HTTP streams/playlists can be intercepted.
- Only use IPTV sources for which you have the rights/access permission.

## Development notes

- This ZIP has not been compiled/tested against the Android SDK inside the creation environment (Flutter SDK unavailable there). The GitHub Action is configured to run `flutter analyze`, `flutter test`, and `flutter build apk` so actual compatibility is verified on a runner. Check CI logs if toolchain APIs or plugin requirements change.
- Supported phones can sideload this build too, but the screen is locked to **landscape** and optimized for television remotes.
- For future real DVB tuner integration, implement Android **TV Input Framework** or an OEM-specific tuner bridge; a regular Flutter IPTV player cannot access private tuner middleware by itself.
