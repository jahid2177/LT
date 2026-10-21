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
assert '.TvHomeActivity' in activities
assert '.CrashFinderActivity' in activities
assert 'com.example.live_tv_remote.MainActivity' in activities
home = activities['.TvHomeActivity']
assert home.attrib[android+'exported'] == 'true'
for category in ['android.intent.category.LEANBACK_LAUNCHER','android.intent.category.LAUNCHER']:
    launchers = [name for name, activity in activities.items() for f in activity.findall('intent-filter')
                 if any(c.attrib.get(android+'name') == category for c in f.findall('category'))]
    assert launchers == ['.TvHomeActivity'], (category, launchers)
assert not activities['.CrashFinderActivity'].findall('intent-filter')
assert not activities['com.example.live_tv_remote.MainActivity'].findall('intent-filter')
package = base / 'kotlin/com/example/live_tv_remote'
for name in ['LiveTvApplication.kt','CrashLogStore.kt','CrashFinderActivity.kt','MainActivity.kt','TvHomeActivity.kt']:
    assert (package / name).is_file(), name
assert 'runZonedGuarded' in (p/'lib/main.dart').read_text()
assert 'PlatformDispatcher.instance.onError' in (p/'lib/main.dart').read_text()
assert 'CrashReporter.firstFrame()' in (p/'lib/main.dart').read_text()
assert 'showCrashFinder' in (package/'MainActivity.kt').read_text()
assert 'defaultChannelsUrl' in (p/'lib/services/playlist_repository.dart').read_text()
assert 'faria2177/live-tv-channels' in (p/'lib/services/playlist_repository.dart').read_text()
workflow = (p/'.github/workflows/android-tv-apk.yml').read_text()
assert 'android-arm,android-arm64' in workflow
assert '--debug --target-platform android-arm' in workflow
assert 'lib/armeabi-v7a/libflutter.so' in workflow
assert 'MOBILE_AUTO_START_MAIN' in (package/'TvHomeActivity.kt').read_text()
print('Single native TV launcher + Crash Finder, ARM32/64 APK, fatal handler, Flutter diagnostics, and GitHub source: OK')
