package com.example.live_tv_remote

import android.media.AudioManager
import android.os.Bundle
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var remoteChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Leave actual VOLUME_UP / VOLUME_DOWN keys with Android TV's audio system.
        setVolumeControlStream(AudioManager.STREAM_MUSIC)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
