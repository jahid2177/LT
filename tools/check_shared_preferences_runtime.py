#!/usr/bin/env python3
"""Fail CI if pub upgrade reintroduces the Android release-only JNI crash."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
pubspec = (root / "pubspec.yaml").read_text()
lock_path = root / "pubspec.lock"
proguard = (root / "android/app/proguard-rules.pro").read_text()
expected = "2.4.28"

if not re.search(r"(?m)^\s{2}shared_preferences_android:\s*" + re.escape(expected) + r"\s*$", pubspec):
    raise SystemExit(f"pubspec.yaml must pin shared_preferences_android to {expected}")
if not lock_path.is_file():
    raise SystemExit("pubspec.lock not found: execute flutter pub get first")
lock = lock_path.read_text()
match = re.search(r'(?m)^  shared_preferences_android:\s*\n(?:(?:    ).*\n)*?    version: "?([0-9.]+)"?\s*$', lock)
if not match:
    raise SystemExit("Cannot find resolved shared_preferences_android version in pubspec.lock")
if match.group(1) != expected:
    raise SystemExit(f"Unsafe shared_preferences_android version {match.group(1)}; expected {expected}")

required = (
    "-keep class kotlin.Unit { *; }",
    "-keep class kotlin.Result { *; }",
    "-keep class kotlin.Result$Failure { *; }",
    "-keep class kotlin.coroutines.Continuation { *; }",
    "-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }",
    "-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }",
)
for rule in required:
    if rule not in proguard:
        raise SystemExit(f"Missing JNI/Kotlin R8 keep rule: {rule}")
print(f"OK: Android shared_preferences_android {expected} pinned; JNI/R8 rules present")
