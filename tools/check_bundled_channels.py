#!/usr/bin/env python3
"""Validate the bundled *fallback* catalog, not an historical channel count.

The live GitHub channels.json feed is the source of truth. Its channel count
may change without requiring an APK update. The bundled asset is used only
if the online feed and the last saved online copy are unavailable.

Usage: python3 tools/check_bundled_channels.py [optional-file-to-check]
"""

import json
import sys
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
asset = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'assets' / 'channels.json'

try:
    channels = json.loads(asset.read_text(encoding='utf-8-sig'))
except (OSError, ValueError) as error:
    raise SystemExit(f'Invalid bundled channel JSON at {asset}: {error}') from error

if not isinstance(channels, list) or not channels:
    raise SystemExit('Bundled fallback channels.json must be a non-empty JSON array.')

# The Dart parser caps catalogs at 5,000 channels for safety.
if len(channels) > 5000:
    raise SystemExit(f'Bundled catalog has {len(channels)} entries (maximum 5000).')

urls = []
for index, item in enumerate(channels, start=1):
    if not isinstance(item, dict):
        raise SystemExit(f'Entry #{index} is not a JSON object.')
    name = item.get('name')
    if not isinstance(name, str) or not name.strip():
        raise SystemExit(f'Entry #{index} has no non-empty channel name.')
    group = item.get('group')
    if group is not None and (not isinstance(group, str) or not group.strip()):
        raise SystemExit(f'Entry #{index} has an invalid group.')
    url = item.get('url')
    if not isinstance(url, str) or not url.strip():
        raise SystemExit(f'Entry #{index} has no stream URL.')
    parsed = urlsplit(url.strip())
    if parsed.scheme not in ('http', 'https') or not parsed.hostname:
        raise SystemExit(f'Entry #{index} has an invalid HTTP(S) stream URL: {url!r}')
    urls.append(url.strip())

unique_urls = len(set(urls))
print(f'PASS: {len(channels)} valid fallback JSON entries; '
      f'{unique_urls} distinct HTTP(S) stream URLs.')
print('INFO: GitHub channels.json is the primary online channel source; '
      'this offline snapshot is not required to contain exactly 513 entries.')
if unique_urls != len(channels):
    print(f'INFO: {len(channels) - unique_urls} repeated stream URL(s) exist; '
          'the Dart parser intentionally de-duplicates matching URLs.')
