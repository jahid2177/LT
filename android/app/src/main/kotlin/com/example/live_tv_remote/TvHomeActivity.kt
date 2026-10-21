package com.example.live_tv_remote

import android.app.Activity
import android.app.UiModeManager
import android.content.Intent
import android.os.Bundle
import android.content.res.Configuration
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/** Native, 32-bit compatible launcher: no Flutter engine, plugin, or video decoder. */
class TvHomeActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CrashLogStore.append(this, "NATIVE_HOME_OPENED", CrashLogStore.deviceSummary())
        // Keep the working mobile experience unchanged: only TV devices need
        // the diagnostic start screen. Both code paths still have native logs.
        val uiMode = (getSystemService(UI_MODE_SERVICE) as UiModeManager).currentModeType
        val isTv = uiMode == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature("android.software.leanback")
        if (!isTv) {
            CrashLogStore.append(this, "MOBILE_AUTO_START_MAIN")
            try {
                startActivity(Intent(this, MainActivity::class.java))
                finish()
                return
            } catch (error: Throwable) {
                CrashLogStore.append(this, "MOBILE_START_FAILED", error.toString())
                Toast.makeText(this, error.toString(), Toast.LENGTH_LONG).show()
            }
        }
        CrashLogStore.append(this, "TV_HOME_OPENED")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(36), dp(20), dp(36), dp(20))
            setBackgroundColor(0xFF0C1425.toInt())
        }
        root.addView(TextView(this).apply {
            text = "LIVE TV REMOTE"
            textSize = 34f
            gravity = Gravity.CENTER
            setTextColor(0xFFFFFFFF.toInt())
        })
        root.addView(TextView(this).apply {
            text = "Android TV diagnostic start screen. Select Start Live TV, " +
                "then return here and open Crash Finder if it closes."
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(0xFFC7D7F0.toInt())
            setPadding(0, dp(15), 0, dp(24))
        })
        val start = Button(this).apply {
            text = "START LIVE TV"
            textSize = 20f
            isFocusable = true
            setOnClickListener {
                CrashLogStore.append(this@TvHomeActivity, "START_TV_BUTTON_PRESSED")
                try {
                    startActivity(Intent(this@TvHomeActivity, MainActivity::class.java))
                } catch (error: Throwable) {
                    CrashLogStore.append(this@TvHomeActivity, "START_TV_INTENT_FAILED", error.toString())
                    Toast.makeText(this@TvHomeActivity, error.toString(), Toast.LENGTH_LONG).show()
                }
            }
        }
        root.addView(start, LinearLayout.LayoutParams(dp(400), dp(68)))
        val crash = Button(this).apply {
            text = "OPEN CRASH FINDER"
            textSize = 18f
            isFocusable = true
            setOnClickListener {
                startActivity(Intent(this@TvHomeActivity, CrashFinderActivity::class.java))
            }
        }
        val margins = LinearLayout.LayoutParams(dp(400), dp(65)).apply { topMargin = dp(12) }
        root.addView(crash, margins)
        root.addView(TextView(this).apply {
            text = CrashLogStore.deviceSummary()
            textSize = 13f
            gravity = Gravity.CENTER
            setTextColor(0xFF9AAAC2.toInt())
            setPadding(0, dp(24), 0, 0)
        })
        setContentView(root)
        start.requestFocus()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
