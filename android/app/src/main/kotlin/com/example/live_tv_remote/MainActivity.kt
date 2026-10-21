package com.example.live_tv_remote

import android.content.Intent
import android.media.AudioManager
import android.os.Bundle
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var remoteChannel: MethodChannel? = null

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
        remoteChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "livetv_remote/keys"
        )
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
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
