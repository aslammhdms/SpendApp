package com.spendsheet.spendsheet

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var walletChannel: MethodChannel? = null

    /** Set when a payment reminder opened the app; the app asks for it. */
    private var openPaymentsRequested = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Not on a restore after the system ended the process: the tap was
        // already handled then.
        if (savedInstanceState == null) noteOpenRequest(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (noteOpenRequest(intent)) {
            // The app is already running: tell it straight away.
            walletChannel?.invokeMethod("openPayments", null)
        }
    }

    private fun noteOpenRequest(intent: Intent?): Boolean {
        if (intent?.action != WalletPaymentNotifier.ACTION_OPEN_PAYMENTS) return false
        openPaymentsRequested = true
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Google Wallet payment capture (see WalletNotificationListener).
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "spendsheet/wallet_capture",
        )
        walletChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAccess" -> result.success(
                    NotificationManagerCompat.getEnabledListenerPackages(this)
                        .contains(packageName)
                )
                "openAccessSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(null)
                }
                "setEnabled" -> {
                    val enabled = call.arguments == true
                    WalletCaptureStore.setEnabled(this, enabled)
                    if (!enabled) WalletPaymentNotifier.clearAll(this)
                    result.success(null)
                }
                "setNotifyEnabled" -> {
                    WalletCaptureStore.setNotifyEnabled(this, call.arguments == true)
                    result.success(null)
                }
                "clearPaymentNotifications" -> {
                    WalletPaymentNotifier.clearAll(this)
                    result.success(null)
                }
                "takeOpenRequest" -> {
                    result.success(openPaymentsRequested)
                    openPaymentsRequested = false
                }
                "drain" -> result.success(WalletCaptureStore.drain(this))
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        walletChannel?.setMethodCallHandler(null)
        walletChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
