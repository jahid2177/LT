# GitHub channels.json integration

## Data source

Default JSON catalog:

https://raw.githubusercontent.com/faria2177/live-tv-channels/refs/heads/main/channels.json

## Added in this version

- First launch fetches JSON channel catalog automatically, without typing URL.
- On later launches, fetches updates from the last online URL.
- Last successfully parsed catalog is cached locally; network failure keeps the cached channel list.
- Manual refresh in channel guide, retry online channels on empty screen.
- Import JSON or M3U through URL, local file, or pasted text.
- JSON parser supports common direct and nested streaming URL fields, arrays, groups, category maps, and duplicate filtering.
- Channel logos appear in the remote-friendly guide when present.
- Existing M3U / remote features remain intact.
- Unit tests added for JSON structures; GitHub Actions still performs Flutter analyze/tests/build.

## Caveats

- The supplied GitHub endpoint was inaccessible from the code creation environment; its actual schema and stream accessibility were **not** verified here. If the live feed uses custom field names, upload `channels.json` for an exact mapping.
- The streaming URL must be a playable media URL. Web pages/iframes, DRM and sources requiring special tokens/headers may not play using the basic video_player.
- Physical CH keys and system volume keys depend on TV firmware. The app also provides D-pad channel controls.
- Flutter toolchain is absent in this environment, so the Android APK build has **not** been verified here.
