package com.spendsheet.spendsheet

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Tells the user right after a Google Wallet payment that it is waiting in
 * SpendSheet, with a tap that opens the payment list.
 */
object WalletPaymentNotifier {
    const val ACTION_OPEN_PAYMENTS = "com.spendsheet.spendsheet.OPEN_WALLET_PAYMENTS"

    private const val CHANNEL_ID = "wallet_payments"
    private const val TAG = "wallet_payment"
    private const val SEED_COLOR = 0xFF6366F1.toInt() // AppColorSchemes.seed

    fun show(context: Context, key: String, payment: WalletPaymentParser.Payment) {
        val manager = NotificationManagerCompat.from(context)
        // Blocked by the user, or permission not granted on Android 13+:
        // the payment still waits in the app's list.
        if (!manager.areNotificationsEnabled()) return
        ensureChannel(context)

        val title = payment.merchant?.let { "$it · ${payment.amountText}" }
            ?: "${payment.amountText} paid with Google Wallet"

        // What a locked screen that hides sensitive content shows instead.
        val publicVersion = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_spendsheet)
            .setColor(SEED_COLOR)
            .setContentTitle("Google Wallet payment")
            .setContentText("Tap to review it in SpendSheet.")
            .build()

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_spendsheet)
            .setColor(SEED_COLOR)
            .setContentTitle(title)
            .setContentText("Tap to add it as an expense.")
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .setContentIntent(openPaymentsIntent(context))
            .setAutoCancel(true)
            .build()

        try {
            manager.notify(TAG, key.hashCode(), notification)
        } catch (e: SecurityException) {
            // Permission withdrawn between the check and the post.
        }
    }

    /** Removes the payment notifications SpendSheet is showing. */
    fun clearAll(context: Context) {
        val system = context.getSystemService(NotificationManager::class.java) ?: return
        for (shown in system.activeNotifications) {
            if (shown.tag == TAG) system.cancel(TAG, shown.id)
        }
    }

    private fun openPaymentsIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(ACTION_OPEN_PAYMENTS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val system = context.getSystemService(NotificationManager::class.java) ?: return
        if (system.getNotificationChannel(CHANNEL_ID) != null) return
        system.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Google Wallet payments",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "A reminder to add each Google Wallet payment as an expense"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            }
        )
    }
}
