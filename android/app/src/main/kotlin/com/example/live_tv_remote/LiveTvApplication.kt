package com.example.live_tv_remote

import android.app.Application

class LiveTvApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        // Installed BEFORE FlutterActivity / plugin registration. No Flutter dependency.
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try { CrashLogStore.reportFatal(this, thread, error) } catch (_: Throwable) { }
            if (previous != null) {
                previous.uncaughtException(thread, error)
            } else {
                // Preserve the normal fatal-exception process semantics.
                android.os.Process.killProcess(android.os.Process.myPid())
                kotlin.system.exitProcess(10)
            }
        }
        CrashLogStore.append(this, "APPLICATION_CREATED", CrashLogStore.deviceSummary())
    }
}
