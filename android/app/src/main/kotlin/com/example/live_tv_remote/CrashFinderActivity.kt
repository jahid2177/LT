package com.example.live_tv_remote

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Dedicated native Android TV screen. Flutter, codecs, and plugins are never started. */
class CrashFinderActivity : Activity() {
    private lateinit var reportView: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CrashLogStore.append(this, "CRASH_FINDER_OPENED")

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(25), dp(16), dp(25), dp(12))
            setBackgroundColor(0xFF0C1425.toInt())
        }
        root.addView(TextView(this).apply {
            text = "LIVE TV - CRASH FINDER"
            textSize = 26f
            setTextColor(0xFFFFFFFF.toInt())
            setPadding(0, 0, 0, dp(8))
        })
        root.addView(TextView(this).apply {
            text = "Runs WITHOUT Flutter. Use TV remote to select an action. " +
                "After the main Live TV app crashes, reopen Crash Finder and choose Save or Share."
            textSize = 16f
            setTextColor(0xFFC7D7F0.toInt())
            setPadding(0, 0, 0, dp(10))
        })

        val actions = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        fun addAction(label: String, operation: () -> Unit) {
            actions.addView(Button(this).apply {
                text = label
                isFocusable = true
                isFocusableInTouchMode = true
                setOnClickListener { operation() }
            }, LinearLayout.LayoutParams(0, dp(54), 1f))
        }
        addAction("Try Live TV") {
            CrashLogStore.append(this, "CRASH_FINDER_START_TV_PRESSED")
            startActivity(Intent(this, MainActivity::class.java))
        }
        addAction("Refresh") { refresh() }
        addAction("Save TXT") { saveReport() }
        addAction("Share") { shareReport() }
        addAction("Copy") { copyReport() }
        addAction("Clear") { CrashLogStore.clear(this); refresh() }
        root.addView(actions)

        val scroll = ScrollView(this).apply { isFocusable = true }
        reportView = TextView(this).apply {
            textSize = 13f
            typeface = android.graphics.Typeface.MONOSPACE
            setTextColor(0xFFF0F4FA.toInt())
            setTextIsSelectable(true)
            setPadding(dp(10), dp(15), dp(10), dp(30))
        }
        scroll.addView(reportView)
        root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        setContentView(root)
        refresh()
        actions.getChildAt(1)?.requestFocus()
    }

    private fun refresh() { reportView.text = CrashLogStore.read(this) }

    private fun shareReport() {
        try {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_SUBJECT, "Live TV Remote Crash Report")
                putExtra(Intent.EXTRA_TEXT, CrashLogStore.read(this@CrashFinderActivity))
            }
            startActivity(Intent.createChooser(send, "Share crash report"))
        } catch (error: Exception) { notifyUser("No sharing app available: ${error.message}") }
    }

    private fun copyReport() {
        val manager = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
        manager.setPrimaryClip(ClipData.newPlainText("Live TV Crash Report", CrashLogStore.read(this)))
        notifyUser("Crash report copied")
    }

    private fun saveReport() {
        val filename = "live_tv_crash_" +
            SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date()) + ".txt"
        val data = CrashLogStore.read(this).toByteArray(Charsets.UTF_8)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
                    put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/LiveTVRemote")
                }
                val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: error("Cannot create Downloads item")
                contentResolver.openOutputStream(uri)?.use { it.write(data) }
                    ?: error("Cannot write Downloads item")
                notifyUser("Saved to Downloads/LiveTVRemote/$filename")
            } else {
                // Android 7-9: use app-specific storage with no permission request.
                val folder = getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS)
                    ?: error("External files unavailable")
                folder.mkdirs()
                val file = File(folder, filename)
                file.writeBytes(data)
                notifyUser("Saved to: ${file.absolutePath}")
            }
        } catch (error: Exception) { notifyUser("Save failed: ${error.message}") }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
    private fun notifyUser(message: String) = Toast.makeText(this, message, Toast.LENGTH_LONG).show()
}
