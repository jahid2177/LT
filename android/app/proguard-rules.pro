# AndroidX WindowManager optionally uses these device/OEM-provided packages.
# They are not packaged with ordinary APKs, and are absent on many Android TVs.
# R8 must not fail simply because these optional vendor APIs are missing.
# Avoid global -ignorewarnings: unrelated missing classes should still fail CI.
-dontwarn androidx.window.extensions.**
-dontwarn androidx.window.sidecar.**
