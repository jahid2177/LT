#!/usr/bin/env python3
"""Customise the generated Flutter Windows runner (run after `flutter create --platforms=windows .`).

* exe name  -> LiveTVRemote.exe, window title / file description -> "Live TV Remote"
* the window opens maximised (TV-like)
* app icon  -> built from the Android launcher icon
"""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
win = root / "windows"
OLD = "live_tv_remote"
NAME = "Live TV Remote"
EXE = "LiveTVRemote"


def patch(rel: str, pairs):
    path = win / rel
    text = path.read_text(encoding="utf-8")
    for old, new in pairs:
        if old not in text:
            print(f"WARN {rel}: '{old}' not found (already patched or template changed)")
            continue
        text = text.replace(old, new)
        print(f"OK   {rel}: {old!r} -> {new!r}")
    path.write_text(text, encoding="utf-8")


patch("CMakeLists.txt", [(f'set(BINARY_NAME "{OLD}")', f'set(BINARY_NAME "{EXE}")')])
patch("runner/main.cpp", [(f'L"{OLD}"', f'L"{NAME}"')])
patch("runner/win32_window.cpp", [("ShowWindow(window_handle_, SW_SHOWNORMAL)",
                                   "ShowWindow(window_handle_, SW_SHOWMAXIMIZED)")])
patch("runner/Runner.rc", [
    (f'"{OLD}.exe"', f'"{EXE}.exe"'),
    (f'"{OLD}" "\\0"', f'"{NAME}" "\\0"'),
])

try:
    from PIL import Image
except ImportError:
    print("WARN Pillow missing; keeping the default Flutter icon")
    sys.exit(0)

src = root / "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
ico = win / "runner/resources/app_icon.ico"
img = Image.open(src).convert("RGBA").resize((256, 256), Image.LANCZOS)
img.save(ico, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print(f"OK   icon written: {ico.relative_to(root)}")
