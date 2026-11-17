#!/usr/bin/env python3
"""Checks every channel stream URL of one or more channel JSON files.

Usage:
  python3 tools/check_stream_links.py --source assets/channels.json \
      --source https://raw.githubusercontent.com/.../channels.json \
      --report report.md --cleaned-dir cleaned

For each channel (a JSON object that has a name and at least one stream URL)
every URL is requested. A channel is
  ok         - at least one URL answered like a live stream
  dead       - every URL is gone (HTTP 404/410, DNS failure, refused connection,
               or an HLS URL that does not return a playlist)
  uncertain  - timeouts, HTTP 403/5xx ...: these can be geo/IP restrictions of the
               machine running this check, so they are NEVER removed automatically.

Nothing in the source is modified. With --cleaned-dir a copy without the
"dead" channels is written next to the report so a person can review it.
The exit status is 0 even when dead channels exist (this is a report), and
non-zero only when a source cannot be read.
"""
import argparse
import concurrent.futures
import json
import socket
import sys
import urllib.error
import urllib.request
from pathlib import Path

URL_KEYS = {
    'url', 'stream_url', 'streamUrl', 'streamURL', 'stream_link', 'playback_url',
    'playbackUrl', 'playUrl', 'play_url', 'video_url', 'videoUrl', 'm3u8', 'hls',
    'stream', 'streams', 'sources', 'signals', 'links', 'urls', 'qualities',
    'playback', 'link', 'src', 'file', 'backup_urls', 'backupUrls', 'backups',
    'backup', 'backup_url', 'backupUrl', 'alt_urls', 'altUrls', 'alt_url',
    'altUrl', 'alternatives', 'fallback', 'fallback_url', 'fallbackUrl',
    'fallbacks', 'mirrors', 'mirror',
}
USER_AGENT = 'Mozilla/5.0 (Linux; Android 11; TV) LiveTVRemote-LinkCheck/1.0'


def load_source(source):
    if source.startswith(('http://', 'https://')):
        req = urllib.request.Request(source, headers={'User-Agent': USER_AGENT})
        with urllib.request.urlopen(req, timeout=30) as response:
            raw = response.read()
    else:
        raw = Path(source).read_bytes()
    return json.loads(raw.decode('utf-8-sig'))


def urls_of(entry):
    """All http(s) stream URLs directly inside one channel object."""
    found = []

    def collect(node, depth=0):
        if depth > 4:
            return
        if isinstance(node, str):
            if node.startswith(('http://', 'https://')) and node not in found:
                found.append(node)
        elif isinstance(node, list):
            for item in node:
                collect(item, depth + 1)
        elif isinstance(node, dict):
            for key, value in node.items():
                if key in URL_KEYS:
                    collect(value, depth + 1)

    for key, value in entry.items():
        if key in URL_KEYS:
            collect(value)
    return found


def walk_channels(node, out, depth=0):
    """Collect channel objects: dicts with a name and at least one URL."""
    if depth > 12:
        return
    if isinstance(node, list):
        for item in node:
            walk_channels(item, out, depth + 1)
    elif isinstance(node, dict):
        name = next((node[k] for k in ('name', 'title', 'channel_name') if isinstance(node.get(k), str)), None)
        urls = urls_of(node)
        if name and urls:
            out.append(node)
            return
        for value in node.values():
            if isinstance(value, (list, dict)):
                walk_channels(value, out, depth + 1)


def probe(url, timeout):
    """Returns 'ok', 'dead' or 'uncertain' plus a short reason."""
    request = urllib.request.Request(url, headers={
        'User-Agent': USER_AGENT, 'Range': 'bytes=0-2047', 'Accept': '*/*'})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            head = response.read(2048)
            code = response.status
    except urllib.error.HTTPError as error:
        if error.code in (404, 410):
            return 'dead', f'HTTP {error.code}'
        return 'uncertain', f'HTTP {error.code}'
    except urllib.error.URLError as error:
        reason = error.reason
        if isinstance(reason, socket.gaierror):
            return 'dead', 'DNS name not found'
        if isinstance(reason, ConnectionRefusedError):
            return 'dead', 'connection refused'
        return 'uncertain', str(reason)[:60]
    except (socket.timeout, TimeoutError):
        return 'uncertain', 'timeout'
    except Exception as error:  # noqa: BLE001 - report, never crash the run
        return 'uncertain', type(error).__name__
    if url.split('?', 1)[0].lower().endswith('.m3u8') and b'#EXTM3U' not in head:
        return 'dead', f'HTTP {code} but not an HLS playlist'
    return 'ok', f'HTTP {code}'


def probe_with_retry(url, timeout):
    result = probe(url, timeout)
    if result[0] == 'uncertain':
        second = probe(url, timeout)
        if second[0] != 'uncertain':
            return second
    return result


def channel_status(statuses):
    values = [s for s, _ in statuses]
    if 'ok' in values:
        return 'ok'
    if values and all(v == 'dead' for v in values):
        return 'dead'
    return 'uncertain'


def prune(node, dead_ids):
    if isinstance(node, list):
        return [prune(x, dead_ids) for x in node if id(x) not in dead_ids]
    if isinstance(node, dict):
        return {k: prune(v, dead_ids) for k, v in node.items() if id(v) not in dead_ids}
    return node


def check_source(source, workers, timeout):
    data = load_source(source)
    channels = []
    walk_channels(data, channels)
    all_urls = sorted({u for c in channels for u in urls_of(c)})
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(probe_with_retry, u, timeout): u for u in all_urls}
        for future in concurrent.futures.as_completed(futures):
            results[futures[future]] = future.result()
    rows, dead_ids = [], set()
    for channel in channels:
        statuses = [results[u] for u in urls_of(channel)]
        status = channel_status(statuses)
        if status == 'dead':
            dead_ids.add(id(channel))
        rows.append((status, channel, statuses))
    return data, rows, dead_ids


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--source', action='append', required=True,
                        help='channel JSON file or URL (repeatable)')
    parser.add_argument('--report', default='stream-link-report.md')
    parser.add_argument('--cleaned-dir', default='')
    parser.add_argument('--workers', type=int, default=24)
    parser.add_argument('--timeout', type=float, default=10.0)
    args = parser.parse_args()

    lines = ['# Stream link check', '']
    failed_sources = 0
    for index, source in enumerate(args.source):
        try:
            data, rows, dead_ids = check_source(source, args.workers, args.timeout)
        except Exception as error:  # noqa: BLE001
            failed_sources += 1
            lines += [f'## {source}', '', f'Could not read this source: `{error}`', '']
            print(f'ERROR reading {source}: {error}', file=sys.stderr)
            continue
        counts = {k: sum(1 for r in rows if r[0] == k) for k in ('ok', 'dead', 'uncertain')}
        lines += [f'## {source}', '',
                  f'{len(rows)} channels: **{counts["ok"]} ok**, '
                  f'**{counts["dead"]} dead**, {counts["uncertain"]} uncertain.', '']
        for title, key in (('Dead (every link is gone)', 'dead'),
                           ('Uncertain (timeout / 403 / 5xx - may be a region or runner limit)', 'uncertain')):
            chosen = [r for r in rows if r[0] == key]
            if not chosen:
                continue
            lines += [f'### {title}', '', '| Channel | Group | Reason | URL |', '|---|---|---|---|']
            for _, channel, statuses in chosen:
                name = str(channel.get('name') or channel.get('title') or channel.get('channel_name'))
                group = str(channel.get('group') or channel.get('category') or '')
                reason = statuses[0][1] if statuses else ''
                url = urls_of(channel)[0] if urls_of(channel) else ''
                lines.append(f'| {name} | {group} | {reason} | `{url}` |')
            lines.append('')
        print(f'{source}: {counts}')
        if args.cleaned_dir and dead_ids:
            out_dir = Path(args.cleaned_dir)
            out_dir.mkdir(parents=True, exist_ok=True)
            cleaned = prune(data, dead_ids)
            target = out_dir / f'cleaned-{index + 1}.json'
            target.write_text(json.dumps(cleaned, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
            lines += [f'A copy without the dead channels was written to `{target.name}` '
                      '(review it before replacing the original).', '']
    Path(args.report).write_text('\n'.join(lines) + '\n', encoding='utf-8')
    return 1 if failed_sources == len(args.source) else 0


if __name__ == '__main__':
    sys.exit(main())
