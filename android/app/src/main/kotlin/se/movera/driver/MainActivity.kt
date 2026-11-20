package se.movera.driver

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
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
        // Contract v0.18.138 (deviceCheck.check, Android): a Play Integrity
        // token (classic request) with the app's binding as the nonce. Any
        // failure answers null: the sign-in request goes without a check.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "movera/device_check",
        ).setMethodCallHandler { call, result ->
            val nonce = call.argument<String>("nonce")
            if (call.method != "playIntegrity" || nonce.isNullOrEmpty()) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            try {
                IntegrityManagerFactory.create(applicationContext)
                    .requestIntegrityToken(IntegrityTokenRequest.builder().setNonce(nonce).build())
                    .addOnSuccessListener { answer -> result.success(answer.token()) }
                    .addOnFailureListener { result.success(null) }
            } catch (_: Exception) {
                result.success(null)
            }
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
