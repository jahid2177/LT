package com.example.live_tv_remote

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Process
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Persistent, dependency-free diagnostics: works before Flutter/plugin initialization. */
object CrashLogStore {
    private const val LIMIT = 200_000
    private const val LOG_NAME = "live_tv_crash_report.txt"
    private const val BOOT_NAME = "last_tv_launch.txt"
    private val lock = Any()

    private fun dir(context: Context): File = File(context.filesDir, "crash_finder")
    private fun stamp(): String = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS Z", Locale.US)
        .format(Date())

    private fun scrub(text: String): String = text
        // Avoid including signed IPTV URL tokens in a shared diagnostic report.
        .replace(Regex("(?i)([?&](?:token|auth|access_token|api_key|key|signature|e|u)=)[^&\\s]+"), "$1[REDACTED]")
        .take(24_000)

    fun append(context: Context, tag: String, details: String = "") {
        try {
            synchronized(lock) {
                val folder = dir(context)
                if (!folder.exists() && !folder.mkdirs()) return
                val output = File(folder, LOG_NAME)
                if (output.exists() && output.length() > LIMIT) {
                    val tail = output.readText(Charsets.UTF_8).takeLast(LIMIT / 2)
                    output.writeText("[Older entries truncated]\n$tail\n", Charsets.UTF_8)
                }
                output.appendText("${stamp()} | ${scrub(tag)} | ${scrub(details)}\n", Charsets.UTF_8)
            }
        } catch (_: Throwable) {
            // Crash capture must never cause another crash.
        }
    }

    fun beginLaunch(context: Context) {
        try {
            synchronized(lock) {
                val folder = dir(context)
                folder.mkdirs()
                val state = File(folder, BOOT_NAME)
                if (state.exists()) {
                    val prior = state.readText(Charsets.UTF_8)
                    if (prior.startsWith("STARTING")) {
                        append(context, "PREVIOUS_TV_STARTUP_INCOMPLETE", prior.trim())
                    }
                }
                state.writeText("STARTING ${stamp()} (pid ${Process.myPid()})\n", Charsets.UTF_8)
            }
        } catch (_: Throwable) { }
        append(context, "TV_MAIN_ACTIVITY_START", deviceSummary())
    }

    fun firstFrame(context: Context) {
        try {
            synchronized(lock) {
                File(dir(context), BOOT_NAME).writeText("FIRST_FRAME_OK ${stamp()}\n", Charsets.UTF_8)
            }
        } catch (_: Throwable) { }
        append(context, "FLUTTER_FIRST_FRAME")
    }

    fun reportFatal(context: Context, thread: Thread, error: Throwable) {
        val writer = StringWriter()
        try { error.printStackTrace(PrintWriter(writer)) } catch (_: Throwable) { }
        append(context, "FATAL_JAVA_CRASH thread=${thread.name}", writer.toString())
    }

    fun deviceSummary(): String = "${Build.MANUFACTURER} ${Build.MODEL}; " +
        "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}); " +
        "ABI ${Build.SUPPORTED_ABIS.joinToString()}; process=${Process.myPid()}"

    private fun recentProcessExits(context: Context): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return "Historical process-exit reasons require Android 11 (API 30)+."
        }
        return try {
            val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val exits = manager.getHistoricalProcessExitReasons(context.packageName, 0, 6)
            if (exits.isEmpty()) {
                "No process exits recorded by Android yet."
            } else {
                exits.joinToString("\n") { info ->
                    val reason = when (info.reason) {
                        android.app.ApplicationExitInfo.REASON_CRASH -> "JAVA_CRASH"
                        android.app.ApplicationExitInfo.REASON_CRASH_NATIVE -> "NATIVE_CRASH"
                        android.app.ApplicationExitInfo.REASON_ANR -> "APP_NOT_RESPONDING"
                        android.app.ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY"
                        android.app.ApplicationExitInfo.REASON_SIGNALED -> "SIGNAL_KILL"
                        android.app.ApplicationExitInfo.REASON_EXIT_SELF -> "EXIT_SELF"
                        else -> "OTHER_${info.reason}"
                    }
                    "${Date(info.timestamp)} pid=${info.pid} reason=$reason " +
                        "status=${info.status} details=${scrub(info.description ?: "-")}"
                }
            }
        } catch (error: Throwable) {
            "Android process exit history unavailable: ${error.javaClass.simpleName}"
        }
    }

    fun read(context: Context): String {
        val folder = dir(context)
        val status = try { File(folder, BOOT_NAME).takeIf { it.exists() }?.readText(Charsets.UTF_8) ?: "No TV launch recorded" }
        catch (_: Throwable) { "Launch state unreadable" }
        val history = try { File(folder, LOG_NAME).takeIf { it.exists() }?.readText(Charsets.UTF_8) ?: "No events recorded yet" }
        catch (_: Throwable) { "Report unreadable" }
        return "Live TV Remote - Crash Finder\n${deviceSummary()}\n\n" +
            "LATEST TV LAUNCH:\n$status\n" +
            "ANDROID PROCESS EXIT HISTORY:\n${recentProcessExits(context)}\n\n" +
            "EVENTS / ERRORS (oldest to newest):\n$history\n" +
            "IMPORTANT: Native SIGSEGV/SIGABRT, low-memory kills and failures " +
            "before Application.onCreate may require ADB logcat or tombstones."
    }

    fun clear(context: Context) {
        try { synchronized(lock) { File(dir(context), LOG_NAME).delete() } }
        catch (_: Throwable) { }
    }
}
