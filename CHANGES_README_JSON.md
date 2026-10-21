# README.json integration update (21 October 2026)

## Supplied file
- `README.json`: valid top-level JSON list with **513** entries, copied unchanged to `assets/channels.json`.
- Every entry has `name`, `logo`, `group`, `url`, `source`, `epg_id`, `epg_name`, and `extinf`.
- The JSON parser already supported these names directly; now tests verify parsing this actual file.
- 513 distinct URL strings, 492 distinct case-insensitive names (21 additional occurrences of reused names).
- 21 HTTP streaming URLs and 492 HTTPS streaming URLs. `AndroidManifest.xml` already permits HTTP; providers and devices can still reject some streams.
- 50 URLs have numeric `e=` timestamps in July 2026, **already past as of 21 October 2026**. These tokenized URLs can return authorization errors. A static list cannot refresh provider-specific signing tokens. A number of additional URLs may also be expired, blocked, DRM-protected, or non-live. None of the links has been playback-verified.
- EPG IDs are empty for every entry; a program guide (broadcast schedule) needs external EPG data.

## Behavior
1. New install: immediately loads bundled snapshot so channels can be browsed even when GitHub is unreachable.
2. App still refreshes from the user-provided GitHub URL. A valid response replaces the current list and is cached in preferences.
3. If remote download fails, keep last saved or bundled list. Loading the list **does not mean the video itself is cached**; playback requires valid network streams.
4. Playlist manager includes **Use bundled README.json channels (513)** to reload snapshot, as well as GitHub JSON/M3U URL, device file, and pasted text imports.
5. Fixes `file_picker` 13.1 API usage (single-file `FilePicker.pickFile`, `PlatformFile.readAsBytes`) to prevent CI compile errors.
6. Aligns Android `minSdk` to **24** for newer `video_player` Android support.
7. Adds `test/bundled_channels_test.dart` to verify full data schema and count.

## Limits
- Does not implement a physical antenna/cable/satellite tuner or decrypt pay-TV/DRM streams.
- Actual streams and remote hardware keys must be tested on a compatible Android TV/Google TV device.
- APK build/test execution cannot be verified locally without an installed Flutter SDK; run GitHub Actions workflow.
- Use only stream links you have rights to access and distribute; this project does not grant distribution rights.
