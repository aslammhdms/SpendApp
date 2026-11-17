package com.spendsheet.spendsheet

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Captures Google Wallet payment notifications so SpendSheet can offer them
 * as expenses.
 *
 * Android delivers every app's notifications to a listener. This one drops
 * everything that is not from Google Wallet without reading it, and does
 * nothing at all unless the user turned capture on in SpendSheet.
 */
class WalletNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null || sbn.packageName != WalletCaptureStore.WALLET_PACKAGE) return
        if (!WalletCaptureStore.isEnabled(this)) return

        val notification = sbn.notification ?: return
        // Group summaries repeat what their child notifications say.
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString().orEmpty()
        if (title.isBlank() && text.isBlank()) return

        WalletCaptureStore.add(this, sbn.key, title, text, sbn.postTime)
    }
}
