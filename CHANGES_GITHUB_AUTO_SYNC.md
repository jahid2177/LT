# GitHub Primary Channel Auto-Sync — 2026-10-21

Source: https://raw.githubusercontent.com/faria2177/live-tv-channels/refs/heads/main/channels.json

- Force GitHub as main startup source; do not accidentally make old imported M3U permanent.
- Download on launch, polling every two minutes while foreground, refresh on resume, manual reload.
- Save validated GitHub JSON to device; fallback saved list then 513-entry bundle if unavailable.
- HTTP conditional GET with ETag where available; no-cache revalidation.
- Stable logical channel identity, retaining favorites and channel selection through URL changes.
- When active channel's URL changes, retune via serialized playback path without multiple decoders.
- Parsing errors never replace last known working catalog.
- Build verification requires GitHub Actions / real Android TV; no SDK available in this environment.
