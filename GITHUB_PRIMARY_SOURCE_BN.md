# Live TV Remote v1.1.8 — GitHub is the primary channel source

**Main channel source:**

`https://raw.githubusercontent.com/faria2177/live-tv-channels/refs/heads/main/channels.json`

- Every fresh app launch first requests this GitHub JSON. It does not show the bundled offline fallback snapshot while a first request is pending.
- A valid HTTP 200 JSON feed replaces the channel catalog. The displayed channel count comes from the live feed; it is **not** hard-coded to 513.
- GitHub is rechecked every two minutes while the app is in the foreground, on app resume (if enough time has passed), and by the guide's Refresh icon.
- ETag/HTTP 304 revalidation uses only a previously validated GitHub catalog, never a bundled snapshot.
- When the JSON changes, added and deleted channels are reflected. If an existing channel's stable identity can be matched, a new URL replaces the old one; Favorites can be preserved by stable identity.
- On a GitHub fetch/parsing failure, the app keeps an existing channel catalog. On first start it tries the last successfully saved GitHub JSON; if unavailable, it uses `assets/channels.json` as an *offline fallback only*.
- Optional manual M3U/JSON imports remain in Settings, but the supplied GitHub URL is restored as the primary source on the next app launch.

## GitHub Actions

Replace the repository contents with the contents of `live_tv_remote/` in the full ZIP. Run the **Android TV APK** workflow. Use the universal ARM32/ARM64 APK for the Haier CANDY Android 11 TV.

## Validation status

The ZIP, Dart code structure, the bundled offline catalog (with a variable entry count), and the new catalog parsing test have been inspected. A full Flutter build/test and physical TV playback test have not been executed in this environment.
