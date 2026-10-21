#!/usr/bin/env python3
"""Validate the exact offline channel snapshot used by Android TV."""
import json
from pathlib import Path

asset = Path(__file__).resolve().parents[1] / 'assets' / 'channels.json'
channels = json.loads(asset.read_text(encoding='utf-8-sig'))
assert isinstance(channels, list), 'Bundled JSON must be an array'
assert len(channels) == 513, f'Expected 513 channels, got {len(channels)}'
urls = []
for index, item in enumerate(channels, 1):
    assert isinstance(item, dict), f'Entry {index} is not a JSON object'
    assert item.get('name'), f'Entry {index} has no channel name'
    assert item.get('group'), f'Entry {index} has no group'
    url = item.get('url')
    assert isinstance(url, str) and url.startswith(('http://', 'https://')), (
        f'Entry {index} has no HTTP(S) URL: {url!r}')
    urls.append(url)
assert len(set(urls)) == len(urls), 'Bundled JSON contains duplicate stream URLs'
assert channels[0]['name'] == 'Ekushey TV'
print(f'PASS: {len(channels)} bundled entries, {len(set(urls))} unique HTTP(S) URLs')
