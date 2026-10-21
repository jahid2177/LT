#!/usr/bin/env python3
"""Fail early on Android build tool versions incompatible with Flutter 3.47.x."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
wrapper = (ROOT / "android/gradle/wrapper/gradle-wrapper.properties").read_text()
settings = (ROOT / "android/settings.gradle.kts").read_text()

def version(source: str, pattern: str, label: str) -> tuple[int, ...]:
    match = re.search(pattern, source)
    if match is None:
        raise SystemExit(f"{label} version not found")
    return tuple(int(part) for part in match.group(1).split("."))

gradle = version(wrapper, r"gradle-([0-9]+(?:\.[0-9]+)+)-(?:bin|all)\.zip", "Gradle")
agp = version(settings, r'id\("com\.android\.application"\) version "([0-9]+(?:\.[0-9]+)+)"', "Android Gradle Plugin")
kgp = version(settings, r'id\("org\.jetbrains\.kotlin\.android"\) version "([0-9]+(?:\.[0-9]+)+)"', "Kotlin Gradle Plugin")
if gradle < (8, 14, 0):
    raise SystemExit(f"Gradle {gradle} is too old: Flutter 3.47.7 needs at least 8.14.0")
if not ((8, 11, 0) <= agp < (9, 0, 0)):
    raise SystemExit(f"AGP {agp} is incompatible with this project's Android API 36/legacy KGP configuration")
if not ((2, 2, 20) <= kgp < (2, 3, 0)):
    raise SystemExit(f"Kotlin Gradle Plugin {kgp} is outside the verified Gradle 8.14 / AGP 8.11.1 compatibility range")
print("Compatible Android build versions:", ".".join(map(str, gradle)), "Gradle /", ".".join(map(str, agp)), "AGP /", ".".join(map(str, kgp)), "KGP")
