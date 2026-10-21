# AndroidX WindowManager optionally uses these device/OEM-provided packages.
# They are not packaged with ordinary APKs, and are absent on many Android TVs.
# R8 must not fail simply because these optional vendor APIs are missing.
# Avoid global -ignorewarnings: unrelated missing classes should still fail CI.
-dontwarn androidx.window.extensions.**
-dontwarn androidx.window.sidecar.**

# Defense in depth for native Pigeon / JNI lookups (Flutter plugins).
# 2.5.0 of shared_preferences_android had a release-only JNI lookup
# regression when R8 renamed Kotlin runtime types. The Android plugin is
# pinned to 2.4.28 above; these narrow rules are kept for other JNI consumers.
# https://github.com/flutter/flutter/issues/194649
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
