package com.example.live_tv_remote

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Self-update through Android's own PackageInstaller (no extra Flutter plugin,
 * no FileProvider). The APK is streamed straight into an install session.
 * Android refuses the update unless it is signed with the same key as the
 * installed app, and asks the viewer to confirm the installation.
 */
object AppUpdater {
    private const val ACTION_STATUS = "com.example.live_tv_remote.UPDATE_INSTALL_STATUS"
    private const val ALLOWED_PREFIX = "https://github.com/jahid2177/LT/releases/download/"
    private const val MAX_APK_BYTES = 300L * 1024 * 1024

    private val main = Handler(Looper.getMainLooper())
    private val busy = AtomicBoolean(false)

    /** Receives (type, percent, message) on the main thread. */
    @Volatile
    var listener: ((String, Int?, String?) -> Unit)? = null

    private fun emit(type: String, percent: Int? = null, message: String? = null) {
        main.post { listener?.invoke(type, percent, message) }
    }

    @Suppress("DEPRECATION")
    fun versionInfo(context: Context): Map<String, Any> {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        val code: Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
        return mapOf("versionCode" to code, "versionName" to (info.versionName ?: ""))
    }

    /** Returns false when the URL is not accepted or a download is already running. */
    fun start(context: Context, url: String): Boolean {
        if (!url.startsWith(ALLOWED_PREFIX, ignoreCase = true)) return false
        if (!busy.compareAndSet(false, true)) return false
        val app = context.applicationContext
        CrashLogStore.append(app, "APP_UPDATE_DOWNLOAD_START")
        Thread({ downloadAndInstall(app, url) }, "app-update").start()
        return true
    }

    private fun downloadAndInstall(context: Context, url: String) {
        var session: PackageInstaller.Session? = null
        var connection: HttpURLConnection? = null
        try {
            connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 30_000
                instanceFollowRedirects = true
                setRequestProperty("Accept", "application/octet-stream")
            }
            val status = connection.responseCode
            if (status != HttpURLConnection.HTTP_OK) {
                throw IllegalStateException("Download server returned HTTP $status")
            }
            val total = connection.contentLength.toLong()
            if (total > MAX_APK_BYTES) throw IllegalStateException("Update file is too large")

            val installer = context.packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(
                PackageInstaller.SessionParams.MODE_FULL_INSTALL
            )
            params.setAppPackageName(context.packageName)
            if (total > 0) params.setSize(total)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // Android 12+: later self-updates may install without a prompt.
                params.setRequireUserAction(
                    PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED
                )
            }
            val sessionId = installer.createSession(params)
            val opened = installer.openSession(sessionId)
            session = opened

            var written = 0L
            var lastPercent = -1
            connection.inputStream.use { input ->
                opened.openWrite("base.apk", 0, if (total > 0) total else -1L).use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        output.write(buffer, 0, count)
                        written += count
                        if (written > MAX_APK_BYTES) {
                            throw IllegalStateException("Update file is too large")
                        }
                        if (total > 0) {
                            val percent = (written * 100 / total).toInt()
                            if (percent != lastPercent) {
                                lastPercent = percent
                                emit("progress", percent)
                            }
                        }
                    }
                    opened.fsync(output)
                }
            }
            if (written == 0L) throw IllegalStateException("Downloaded update is empty")

            val callback = Intent(context, UpdateInstallReceiver::class.java)
                .setAction(ACTION_STATUS)
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // The system fills in the result extras, so it must be mutable.
                flags = flags or PendingIntent.FLAG_MUTABLE
            }
            val pending = PendingIntent.getBroadcast(context, sessionId, callback, flags)
            CrashLogStore.append(context, "APP_UPDATE_COMMIT", "bytes=$written")
            opened.commit(pending.intentSender)
            opened.close()
            session = null
            emit("confirm")
        } catch (error: Throwable) {
            CrashLogStore.append(context, "APP_UPDATE_FAILED", error.toString())
            try { session?.abandon() } catch (_: Throwable) { }
            busy.set(false)
            emit("failed", message = error.message ?: error.javaClass.simpleName)
        } finally {
            try { connection?.disconnect() } catch (_: Throwable) { }
        }
    }

    /** Called by [UpdateInstallReceiver] with the installer's verdict. */
    @Suppress("DEPRECATION")
    fun onInstallStatus(context: Context, intent: Intent) {
        val status = intent.getIntExtra(
            PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE
        )
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: ""
        CrashLogStore.append(context, "APP_UPDATE_STATUS", "status=$status $message")
        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                if (confirm == null) {
                    busy.set(false)
                    emit("failed", message = "Android did not provide an install prompt")
                    return
                }
                try {
                    confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirm)
                    emit("confirm")
                } catch (error: Throwable) {
                    busy.set(false)
                    emit("failed", message = "Cannot open the installer: ${error.message}")
                }
            }
            PackageInstaller.STATUS_SUCCESS -> {
                busy.set(false)
                emit("success")
            }
            else -> {
                busy.set(false)
                emit("failed", message = message.ifEmpty { "Installation failed ($status)" })
            }
        }
    }
}

/** Manifest-registered and not exported: only Android's installer result reaches it. */
class UpdateInstallReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AppUpdater.onInstallStatus(context, intent)
    }
}
