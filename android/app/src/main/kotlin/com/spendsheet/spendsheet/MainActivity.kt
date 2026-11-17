package com.spendsheet.spendsheet

import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Google Wallet payment capture (see WalletNotificationListener).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "spendsheet/wallet_capture")
            .setMethodCallHandler { call, result ->
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
                        WalletCaptureStore.setEnabled(this, call.arguments == true)
                        result.success(null)
                    }
                    "drain" -> result.success(WalletCaptureStore.drain(this))
                    else -> result.notImplemented()
                }
            }
    }
}
