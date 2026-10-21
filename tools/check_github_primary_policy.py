#!/usr/bin/env python3
"""Static CI guard for GitHub-first startup and offline-only fallback.
This does not replace Dart analyzer, Flutter tests or an online connectivity test.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
screen = (ROOT / 'lib/screens/live_tv_screen.dart').read_text()
repo = (ROOT / 'lib/services/playlist_repository.dart').read_text()
readme = (ROOT / 'GITHUB_PRIMARY_SOURCE_BN.md').read_text()
startup = screen.split('Future<void> _restore() async {', 1)[1].split('Future<void> _showOfflineCatalog() async {', 1)[0]
online = screen.split('Future<void> _refreshChannels(String url) async {', 1)[1].split('Future<void> _setPlaylist(', 1)[0]
expected = 'https://raw.githubusercontent.com/faria2177/live-tv-channels/refs/heads/main/channels.json'
checks = {
    'exact GitHub URL': expected in repo and expected in readme,
    'online-first startup': 'unawaited(_refreshChannels(sourceUrl));' in startup,
    'no bundled snapshot in startup': '_repository.loadBundledChannels()' not in startup,
    'fallback only after fetch failure': 'await _showOfflineCatalog();' in online.split('} catch (error, stack) {', 1)[-1],
    'periodic two-minute fetch': 'Duration(minutes: 2)' in screen,
    'fetched list replaces current': 'PlaylistSelection(text: content, url: url, channels: channels)' in online,
    '304 only when GitHub cache is verified': 'primary && _hasValidatedOnlineCache' in online,
    'JSON stream URLs parsed': 'const JsonChannelParser().parse(source, baseUri: baseUri)' in repo,
}
for title, passed in checks.items():
    print(('PASS' if passed else 'FAIL') + ': ' + title)
if not all(checks.values()):
    sys.exit(1)
