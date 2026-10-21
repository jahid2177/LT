#!/usr/bin/env python3
"""Static checks for the independent native Crash Finder (no Flutter SDK needed)."""
from pathlib import Path
import xml.etree.ElementTree as ET
p = Path(__file__).resolve().parents[1]
base = p / 'android/app/src/main'
xml = ET.parse(base / 'AndroidManifest.xml').getroot()
android = '{http://schemas.android.com/apk/res/android}'
app = xml.find('application')
assert app is not None and app.attrib.get(android+'name') == '.LiveTvApplication'
activities = {x.attrib.get(android+'name'): x for x in app.findall('activity')}
assert '.CrashFinderActivity' in activities
finder = activities['.CrashFinderActivity']
assert finder.attrib[android+'exported'] == 'true'
filters = finder.findall('intent-filter')
assert any(any(c.attrib.get(android+'name') == 'android.intent.category.LEANBACK_LAUNCHER'
                   for c in f.findall('category')) for f in filters)
assert any(any(c.attrib.get(android+'name') == 'android.intent.category.LAUNCHER'
                   for c in f.findall('category')) for f in filters)
package = base / 'kotlin/com/example/live_tv_remote'
for name in ['LiveTvApplication.kt','CrashLogStore.kt','CrashFinderActivity.kt','MainActivity.kt']:
    assert (package / name).is_file(), name
assert 'runZonedGuarded' in (p/'lib/main.dart').read_text()
assert 'PlatformDispatcher.instance.onError' in (p/'lib/main.dart').read_text()
assert 'CrashReporter.firstFrame()' in (p/'lib/main.dart').read_text()
assert 'showCrashFinder' in (package/'MainActivity.kt').read_text()
assert 'defaultChannelsUrl' in (p/'lib/services/playlist_repository.dart').read_text()
assert 'faria2177/live-tv-channels' in (p/'lib/services/playlist_repository.dart').read_text()
print('Crash Finder native launcher, fatal handler, Flutter diagnostics, and GitHub channel source: OK')
