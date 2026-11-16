package com.example.live_tv_remote

import android.content.Intent
import android.media.AudioManager
import android.os.Bundle
import android.view.KeyEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var remoteChannel: MethodChannel? = null
    private var updaterChannel: MethodChannel? = null
    private var keepAwakeRequested = false
    private var activityResumed = false

    // FLAG_KEEP_SCREEN_ON prevents ordinary Android TV Ambient Mode / display
    // inactivity timeout during playback. This is NOT a CPU wake lock.
    private fun updateKeepScreenOn() {
        if (keepAwakeRequested && activityResumed) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    override fun onResume() {
        super.onResume()
        activityResumed = true
        updateKeepScreenOn()
    }

    override fun onPause() {
        // Allow TV to sleep normally when the app is not visible.
        activityResumed = false
        updateKeepScreenOn()
        super.onPause()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        CrashLogStore.beginLaunch(this)
        super.onCreate(savedInstanceState)
        CrashLogStore.append(this, "MAIN_ACTIVITY_CREATED")
        // Leave actual VOLUME_UP / VOLUME_DOWN keys with Android TV's audio system.
        setVolumeControlStream(AudioManager.STREAM_MUSIC)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        CrashLogStore.append(this, "FLUTTER_ENGINE_REGISTER_BEGIN")
        super.configureFlutterEngine(flutterEngine)
        CrashLogStore.append(this, "FLUTTER_ENGINE_REGISTERED")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "livetv_remote/crash_finder")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "breadcrumb" -> {
                            CrashLogStore.append(this, "DART_STAGE", call.argument<String>("message") ?: "")
                            result.success(null)
                        }
                        "reportError" -> {
                            CrashLogStore.append(this, "DART_ERROR", "${call.argument<String>("source") ?: "unknown"}: ${call.argument<String>("message") ?: ""}\n${call.argument<String>("stack") ?: ""}")
                            result.success(null)
                        }
                        "firstFrame" -> {
                            CrashLogStore.firstFrame(this)
                            result.success(null)
                        }
                        "showCrashFinder" -> {
                            startActivity(Intent(this, CrashFinderActivity::class.java))
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Throwable) {
                    CrashLogStore.append(this, "CRASH_CHANNEL_ERROR", error.toString())
                    result.error("DIAGNOSTICS_FAILED", error.message, null)
                }
            }
        // No additional Flutter plugins are needed (important for older TVs
        // and the SharedPreferences/R8 runtime issues previously diagnosed).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "livetv_remote/screen_awake")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setKeepAwake" -> {
                        val enabled = call.arguments as? Boolean
                        if (enabled == null) {
                            result.error("INVALID_ARGUMENT", "Expected a Boolean", null)
                        } else {
                            if (keepAwakeRequested != enabled) {
                                CrashLogStore.append(this, "SCREEN_AWAKE", "requested=$enabled")
                            }
                            keepAwakeRequested = enabled
                            updateKeepScreenOn()
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        remoteChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "livetv_remote/keys"
        )
        // In-app self-update from this project's GitHub Releases.
        val updater = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "livetv_remote/updater"
        )
        updater.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "getVersion" -> result.success(AppUpdater.versionInfo(this))
                    "installUpdate" -> {
                        val url = call.argument<String>("url") ?: ""
                        if (AppUpdater.start(this, url)) {
                            result.success(null)
                        } else {
                            result.error("UPDATE_REJECTED", "Update already running or URL not allowed", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                CrashLogStore.append(this, "UPDATER_CHANNEL_ERROR", error.toString())
                result.error("UPDATER_FAILED", error.message, null)
            }
        }
        updaterChannel = updater
        AppUpdater.listener = { type, percent, message ->
            updaterChannel?.invokeMethod(
                "onUpdateEvent",
                mapOf("type" to type, "percent" to percent, "message" to message)
            )
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
            val key = when (event.keyCode) {
                KeyEvent.KEYCODE_CHANNEL_UP -> "channelUp"
                KeyEvent.KEYCODE_CHANNEL_DOWN -> "channelDown"
                KeyEvent.KEYCODE_GUIDE -> "guide"
                KeyEvent.KEYCODE_MENU -> "menu"
                else -> null
            }
            if (key != null && remoteChannel != null) {
                remoteChannel?.invokeMethod("onRemoteKey", key)
                return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        remoteChannel = null
        AppUpdater.listener = null
        updaterChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
