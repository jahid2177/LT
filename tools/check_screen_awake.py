#!/usr/bin/env python3
"""Static build guard for Flutter-to-native TV keep-screen-awake wiring."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
kotlin = (root / "android/app/src/main/kotlin/com/example/live_tv_remote/MainActivity.kt").read_text()
flutter = (root / "lib/screens/live_tv_screen.dart").read_text()
policy = (root / "lib/services/screen_awake_policy.dart").read_text()
workflow = (root / ".github/workflows/android-tv-apk.yml").read_text()

required = {
    "native Android window keep-on": "WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON" in kotlin,
    "native channel": '"livetv_remote/screen_awake"' in kotlin,
    "native call handler": '"setKeepAwake"' in kotlin,
    "lifecycle pause cleanup": 'override fun onPause()' in kotlin and 'activityResumed = false' in kotlin,
    "lifecycle resume restoration": 'override fun onResume()' in kotlin and 'activityResumed = true' in kotlin,
    "Flutter channel": "MethodChannel('livetv_remote/screen_awake')" in flutter,
    "Flutter native invocation": "invokeMethod<void>('setKeepAwake', enabled)" in flutter,
    "Flutter lifecycle update": "_foreground = state == AppLifecycleState.resumed;\n    _syncScreenAwake();" in flutter,
    "channel tune update": "_syncScreenAwake(); // Keep TV on" in flutter,
    "player failure update": "_syncScreenAwake();" in flutter,
    "app dispose cleanup": "_requestScreenAwake(false)" in flutter,
    "only while foreground": "appIsForeground &&" in policy,
    "no WAKE_LOCK permission": 'android.permission.WAKE_LOCK' not in (root / 'android/app/src/main/AndroidManifest.xml').read_text(),
    "GitHub test command": "flutter test" in workflow,
}
for name, ok in required.items():
    print(("OK  " if ok else "FAIL"), name)
if not all(required.values()):
    raise SystemExit("Screen-awake integration check failed")
print("TV Keep Screen Awake wiring: OK")
