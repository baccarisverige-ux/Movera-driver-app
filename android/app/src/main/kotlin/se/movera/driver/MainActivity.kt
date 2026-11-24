package se.movera.driver

import android.Manifest
import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONObject

// Stripe PaymentSheet (Pay Movera, DRAFT) needs a FragmentActivity and an AppCompat theme.
class MainActivity : FlutterFragmentActivity() {
    private var pending: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // v0.18.157 (owner 2026-11-24 "Add to admin all kind of crash"): before the Flutter engine starts.
        MoveraCrashCatcher.install(applicationContext)
        super.onCreate(savedInstanceState)
        createOfferChannels()
    }

    // BQ-V43 (G4 decision 1 + E6, contract driverOffers.push.native): the
    // server sends Exclusive and hand-sent offers on "movera_offers" (Movera
    // offer sound, vibration, high importance) and Radar offers on
    // "movera_offers_quiet" (no sound, no vibration). Android keeps a
    // channel once made; making it again only renames it.
    private fun createOfferChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val sound = Uri.parse("android.resource://" + packageName + "/" + R.raw.movera_offer)
        val audio = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val loud = NotificationChannel(
            "movera_offers",
            getString(R.string.offer_channel),
            NotificationManager.IMPORTANCE_HIGH,
        )
        loud.setSound(sound, audio)
        loud.enableVibration(true)
        loud.vibrationPattern = longArrayOf(0, 300, 150, 300)
        val quiet = NotificationChannel(
            "movera_offers_quiet",
            getString(R.string.offer_quiet_channel),
            NotificationManager.IMPORTANCE_DEFAULT,
        )
        quiet.setSound(null, null)
        quiet.enableVibration(false)
        manager.createNotificationChannels(listOf(loud, quiet))
    }

    // D14-7: Android 13+ needs POST_NOTIFICATIONS for the "Movera is online"
    // notice; Go online asks once (lib/core/push/notification_permission.dart).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Audit 2026-11-20 item 2: the screen stays on during an active trip
        // (lib/core/device/screen_awake.dart); a window flag, no permission.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "se.movera.driver/screen",
        ).setMethodCallHandler { call, result ->
            if (call.method != "keepOn") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (call.arguments == true) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
            result.success(null)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "se.movera.driver/notifications",
        ).setMethodCallHandler { call, result ->
            if (call.method != "request") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (Build.VERSION.SDK_INT < 33 ||
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
            ) {
                result.success(true)
                return@setMethodCallHandler
            }
            if (pending != null) {
                result.success(false)
                return@setMethodCallHandler
            }
            pending = result
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), ASK)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != ASK) return
        pending?.success(
            grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
        pending = null
    }

    private companion object {
        const val ASK = 7914
    }
}

/**
 * v0.18.157 crash catcher (contract.json#crashCatcher.nativeReason), no third-party SDK: an uncaught Java/Kotlin
 * exception writes its class, message and stack to files/movera_native_crash.json (then the previous handler runs, so
 * Android closes the app as before); on Android 11+ the last ApplicationExitInfo names a native crash, an ANR or a
 * crash when no file was written (each exit once). movera_device.json carries the model and the Android version. The
 * Dart side reads and deletes the crash file at the next launch. Keep the names in step with crash_files.dart.
 */
object MoveraCrashCatcher {
    @Volatile private var installed = false

    fun install(context: Context) {
        if (installed) return
        installed = true
        try {
            val dir = context.filesDir
            val crashFile = File(dir, "movera_native_crash.json")
            File(dir, "movera_device.json").writeText(
                JSONObject()
                    .put("model", "${Build.MANUFACTURER} ${Build.MODEL}".take(80))
                    .put("os", "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})")
                    .toString(),
            )
            val previous = Thread.getDefaultUncaughtExceptionHandler()
            Thread.setDefaultUncaughtExceptionHandler { thread, error ->
                try {
                    if (!crashFile.exists()) {
                        crashFile.writeText(
                            JSONObject()
                                .put("name", error.javaClass.name)
                                .put("reason", (error.message ?: "").take(1000))
                                .put("stack", Log.getStackTraceString(error).take(12000))
                                .put("thread", thread.name)
                                .toString(),
                        )
                    }
                } catch (_: Throwable) {
                }
                previous?.uncaughtException(thread, error)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) lastExit(context, crashFile)
        } catch (_: Throwable) {
            // The catcher must never stop the app from starting.
        }
    }

    private fun lastExit(context: Context, crashFile: File) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        try {
            val manager = context.getSystemService(ActivityManager::class.java) ?: return
            val last = manager.getHistoricalProcessExitReasons(context.packageName, 0, 1).firstOrNull() ?: return
            val prefs = context.getSharedPreferences("movera_crash_catcher", Context.MODE_PRIVATE)
            if (prefs.getLong("lastExitAt", 0L) == last.timestamp) return
            prefs.edit().putLong("lastExitAt", last.timestamp).apply()
            val name = when (last.reason) {
                ApplicationExitInfo.REASON_CRASH_NATIVE -> "REASON_CRASH_NATIVE"
                ApplicationExitInfo.REASON_ANR -> "REASON_ANR"
                ApplicationExitInfo.REASON_CRASH -> "REASON_CRASH"
                else -> return
            }
            if (crashFile.exists()) return
            crashFile.writeText(
                JSONObject()
                    .put("name", name)
                    .put("reason", (last.description ?: "").take(1000))
                    .put("stack", "")
                    .toString(),
            )
        } catch (_: Throwable) {
        }
    }
}
