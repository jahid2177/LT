> **v1.1.8 GitHub-first mode:** On launch, the app checks the online `channels.json` before showing any cached/bundled channels. A previous GitHub copy or bundled offline JSON is shown only after online loading fails. See [GITHUB_PRIMARY_SOURCE_BN.md](GITHUB_PRIMARY_SOURCE_BN.md).

## GitHub Live Channel Sync (primary source)

**Primary online source:**
`https://raw.githubusercontent.com/faria2177/live-tv-channels/refs/heads/main/channels.json`

- At EVERY app start, this URL is selected as the main source, including for users who previously imported local/M3U playlists.
- The app fetches the live GitHub JSON **before displaying channel data**. A previously validated saved GitHub JSON is shown only if the online fetch fails; the bundled `assets/channels.json` is the final offline fallback, never the authoritative list.
- While the app remains open, it checks GitHub every **2 minutes**; returning from the background also triggers a check (minimum 30s between checks). A manual Refresh control is available. This is **polling, not instant push**; GitHub/CDN caching or device connectivity can delay changes.
- Conditional HTTP (`ETag` / `If-None-Match`) and `Cache-Control: no-cache` minimize unnecessary downloads when supported by GitHub.
- If a channel keeps the same EPG ID or (group, name, duplicate position), a changed stream URL is treated as **the same channel**; if currently playing, the old player is disposed and the new URL is started. Favorites and last-channel selection use stable channel IDs rather than URL.
- A temporary custom playlist can still be selected from Settings; the primary GitHub list is restored on next startup.
- No update to the APK is required when `channels.json` is changed. The file needs to be publicly accessible and well-formed, and each stream must be legitimately accessible to the viewer.
- URLs with expired signed tokens, DRM, blocked origins, or unsupported codecs will not play until the remote source provides a valid URL.

> **TV startup-crash diagnostic build (21 Oct 2026):** The app initially shows the channel guide instead of starting an unverified HLS stream immediately. Press **OK** to watch. GitHub Actions also creates a separate debug APK for diagnosis. For instructions see [`TV_CRASH_CHECK_BN.md`](TV_CRASH_CHECK_BN.md) and [`TV_CRASH_DIAGNOSTICS_BN.md`](TV_CRASH_DIAGNOSTICS_BN.md). This mitigates a possible cause; an actual Android TV crash log is needed to establish the root cause.

# Live TV Remote — Flutter + Android TV

Android TV / Google TV-এর জন্য **remote-first IPTV Live TV app**, written in Flutter (Dart) + a small Kotlin Android remote-key bridge.

> ⚠️ **What this project is / is not**
> This app plays **user-supplied, authorized network TV streams** from JSON channel catalogs or M3U playlists. It is **not** an Android hardware DVB-T/C/S tuner application and it does not read proprietary built-in TV broadcast channel lists. Hardware tuner access requires an OEM tuner/TV Input Framework integration and appropriate permissions. This ZIP bundles the user-uploaded `README.json` as an offline catalog snapshot; the stream URLs are not verified and any rights to access or distribute channels remain the user's responsibility.

## Features

- Android TV / Google TV leanback launcher banner + standard launcher
- Full-screen, landscape, immersive player (video_player / Android ExoPlayer backend)
- JSON and M3U channels using **HTTP/HTTPS HLS `.m3u8`**, DASH/MP4 when supported by the underlying player
- Remote hardware **CH+ / CH−** (Android key codes 166 and 167)
- D-pad **UP/DOWN** switches channels when guide is hidden, navigates the guide when open
- D-pad **OK/Select** opens channel guide / tunes selected channel
- D-pad **LEFT/RIGHT**, MENU / GUIDE and BACK for navigation
- Remote numbers **1–9, 0** for direct channel number entry
- **VOLUME+ / VOLUME−** delegated to Android TV's normal system/media-volume control (not emulated in Flutter)
- Default **GitHub JSON channel source** (from the user), auto-downloaded on first launch and refreshed on later launches:
  `https://raw.githubusercontent.com/faria2177/live-tv-channels/refs/heads/main/channels.json`
- JSON / M3U import from URL, Android file picker (where provided), or pasted text
- Bundled **offline JSON snapshot** as offline-only *list* fallback after a failed GitHub fetch; successful GitHub data replaces it
- Manual refresh and explicit restore of the bundled snapshot from Manage channels
- Favorite/unfavorite, favorites-only guide, last channel on relaunch
- Stream loading/error and retry UI
- **Keep Screen Awake while watching Live TV** (native Android `FLAG_KEEP_SCREEN_ON`); releases automatically when app is backgrounded or no channel is playing. See [`KEEP_SCREEN_AWAKE_BN.md`](KEEP_SCREEN_AWAKE_BN.md). Some Android 11 TVs have a separate system-wide auto-standby setting that apps cannot override.
- Demo M3U with sample test videos for checking the playback pipeline (these are **not live TV channels**)
- GitHub Actions: static analysis, unit tests, build a **universal ARM32 + ARM64 release APK**, upload as downloadable artifact

## Remote controls

| Remote key | Playback screen | Channel guide |
|---|---|---|
| CH+ / CH− | Next / previous channel | Next / previous channel (guide closes) |
| D-pad UP / DOWN | Previous / next channel | Move channel highlight; UP from first row enters toolbar, DOWN returns to list |
| D-pad LEFT | Open guide | Move to previous toolbar icon; on channel list, close guide |
| D-pad RIGHT | Show channel info | Open top toolbar from channel list / move to next icon |
| OK / SELECT / Enter | Open guide | Tune selected channel / activate selected toolbar icon |
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
4. After a successful run, download **Live-TV-Remote-AndroidTV-ARM32-ARM64-Universal** under **Artifacts**. Inside is `app-release.apk`.
5. Copy APK to TV (USB/ADB) and sideload. Allow installing from the relevant source if prompted.

This GitHub-ready repository stores the custom Android TV source and configuration, while letting Flutter generate missing standard platform boilerplate (including the Gradle wrapper JAR) on first build. It avoids bundling SDK-generated binary files in this ZIP.

### Local build (Flutter SDK installed)

```sh
flutter create --platforms=android --project-name=live_tv_remote --org=com.example --no-pub .
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm,android-arm64
```

APK path: `build/app/outputs/flutter-apk/app-release.apk`.

**Requirements:** recent Flutter stable supporting Dart 3.12+, JDK 17 and an installed Android SDK. Android minSdk 24. File picker integration uses v13 APIs. CI sets up Flutter and Java. CI uses the default debug keystore to sign a release-mode sideload APK; use your own secure signing key for Play Store deployment.

## Load TV channels

1. Start app; it fetches the GitHub `channels.json` URL as the **primary source** and shows its live channel count. Only when GitHub cannot be reached or the JSON is invalid will the app display a saved GitHub catalog or the bundled offline snapshot. You do not need to paste the URL.
2. Press **OK** to open the guide and change channels with the remote. The built-in guide has a **Refresh online channels** action for manually checking updates.
3. To add another source, open **Manage JSON / M3U channels**, paste your URL or import a file. You can return to the default GitHub source using **Use supplied GitHub channels.json** or load the bundled file using **Use bundled README.json channels (513)**.

### Notes on your supplied GitHub catalog

The JSON URL is configured in `PlaylistRepository.defaultChannelsUrl`. Your uploaded `README.json` is embedded unchanged as `assets/channels.json` and is parsed only when the GitHub request fails, or when the user explicitly chooses it. Future GitHub updates replace it at runtime when the online fetch succeeds. Both routes use the real `name`, `logo`, `group`, `url` fields. The uploaded data contains **513 entries with 513 distinct URL strings** (492 distinct case-insensitive channel names), including **21 HTTP** and **492 HTTPS** URLs. **50 URLs have `e=` expiry timestamps in July 2026**, before the current date (October 21, 2026); provider authorization may reject them. `epg_id` is blank in all entries. Playback of any channel remains unverified; no client can regenerate a provider's private token or bypass DRM. See `CHANGES_README_JSON.md`.

#### Other ways to load sources
1. Paste your IPTV provider's **JSON/M3U URL** and select **Load from URL**, or load a local file / paste the entire catalog.
2. Press **OK** to open the channel guide, use **D-pad UP/DOWN + OK**, or hardware **CH+ / CH−** to switch.
3. Use the favorites button in the info overlay (or keyboard `F`) to save favorites.

Minimal supported M3U example:

```m3u
#EXTM3U
#EXTINF:-1 tvg-id="news" group-title="News" tvg-logo="",My Licensed News Channel
https://your-authorized-server.example/live/news.m3u8
#EXTINF:-1 tvg-id="sport" group-title="Sports",My Licensed Sports Channel
https://your-authorized-server.example/live/sports.m3u8
```

Replace example domains with **streams you have permission to watch**. JSON/M3U lists may be cached locally. On every app launch, the primary GitHub source takes precedence and is requested first. The last verified GitHub catalog remains available as offline fallback.

### Supported / not yet supported

| Feature | State |
|---|---|
| HLS network playback | Implemented; stream/provider-dependent |
| Bundled uploaded README.json (offline fallback) | Integrated and parser regression test added |
| Default GitHub JSON + auto-refresh/cache | Added; live endpoint and actual streams not verified here |
| URL / local JSON or M3U / pasted text | Implemented |
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
│   ├── services/json_channel_parser.dart  # JSON channel parser
│   ├── services/playlist_repository.dart  # Persistence + HTTP M3U fetch
│   └── screens/
│       ├── live_tv_screen.dart            # Player + guide + remote UI
│       └── playlist_dialog.dart           # URL/file/text playlist input
├── assets/demo_playlist.m3u
├── assets/channels.json                   # Copy of uploaded README.json, 513 entries
├── test/widget_test.dart                  # M3U & remote channel tests
├── test/json_channel_parser_test.dart    # JSON catalog unit tests
├── test/bundled_channels_test.dart        # Real uploaded JSON regression tests
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

## 21 Oct 2026 — Android R8 missing optional WindowManager classes (build fix)

The next GitHub Actions log (`logs_107179239559.zip`) confirms Gradle toolchain verification, clean Dart analysis, and **11 passing tests**, but the release build failed during `:app:minifyReleaseWithR8` because OEM-provided `androidx.window.extensions` and `androidx.window.sidecar` classes were missing. Added **scoped** `-dontwarn` rules in `android/app/proguard-rules.pro` and linked them in the release Gradle config. Full details: [BUILD_FIX_R8_2026-10-21.md](BUILD_FIX_R8_2026-10-21.md).

No blanket `-ignorewarnings` or R8 disablement is used. The 513-channel JSON snapshot has not changed. The follow-up release build still needs validation in GitHub Actions.


## Android TV `SharedPreferencesApiRegistrar.getAll` startup crash — 2026-10-21

Android release startup bug in `shared_preferences_android` 2.5.0 fixed by pinning **2.4.28** and adding targeted Kotlin R8 keep rules. CI checks the resolved version to prevent regression. See [`FIX_ANDROID_TV_SHARED_PREFS_BN.md`](FIX_ANDROID_TV_SHARED_PREFS_BN.md) for Bengali testing instructions. GitHub `channels.json` stays the primary, auto-refreshed source.

## Android TV remote focus and direct startup (v1.1.5)

Android TV now launches **directly into the Flutter channel guide/player**.
The temporary blue diagnostic Start Screen and its **OPEN CRASH FINDER** button
have been removed. The independent native Crash Finder still exists, but can
be opened from the **bug icon in the channel-guide toolbar** or by ADB:

```bash
adb shell am start -n com.example.live_tv_remote/.CrashFinderActivity
```

In the channel guide, press **UP from the first channel** (or **RIGHT from
any channel**) to focus the toolbar. Press **LEFT/RIGHT** to choose Favorites,
Refresh GitHub, Crash Finder, Settings, or Close, then **OK** to activate.
Press **DOWN** to return to the channel list. The focused icon has a visible
white/blue border. Mobile touch input remains enabled.

The GitHub JSON source, two-minute automatic refresh, offline cache and 513
bundled channels are unchanged. Run the GitHub Actions Flutter tests and APK
build to validate on an actual Android TV device.


## v1.1.7 — Search Bar + bundled JSON checks

The TV Channel Guide has a Search Bar between the action toolbar and channel list.
Use D-pad Up from the first channel, press OK to open the Android TV keyboard,
then search by channel name, group or channel number.

Bundled channel tests now read via Flutter `rootBundle` rather than assuming a
filesystem working directory. GitHub Actions validates the bundled entries without a fixed channel count
before `flutter test -r expanded`. See `SEARCH_AND_BUNDLED_TEST_FIX_BN.md`.


## v1.1.9 — Dynamic fallback JSON validation

The GitHub channel feed is authoritative. The online list can have 511, 513, or
any other number of valid channels (up to the parser safety limit) without
changing the APK. GitHub Actions checks the bundled *offline fallback* JSON
for well-formed entries and valid HTTP(S) URLs, but no longer requires exactly
513 entries. Dart regression tests derive the expected count from the bundled
asset, and correctly account for duplicate stream URLs that the parser removes.
`assets/channels.json` is **not** overwritten by this patch; keep your latest
GitHub copy if it currently has 511 entries.
