package com.spendsheet.spendsheet

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Holds Google Wallet notifications until the Flutter side collects them.
 *
 * The listener service can run while the app's UI is closed, so captured
 * notifications wait here (in private app storage) and are handed over the
 * next time the app opens.
 */
object WalletCaptureStore {
    const val WALLET_PACKAGE = "com.google.android.apps.walletnfcrel"

    private const val PREFS = "wallet_capture"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_PENDING = "pending"
    private const val MAX_PENDING = 200
    private const val KEY_NOTIFY = "notify"
    private const val KEY_NOTIFIED = "notified"
    private const val MAX_NOTIFIED = 50

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ENABLED, false)

    @Synchronized
    fun setEnabled(context: Context, enabled: Boolean) {
        val editor = prefs(context).edit().putBoolean(KEY_ENABLED, enabled)
        if (!enabled) editor.remove(KEY_PENDING).remove(KEY_NOTIFIED)
        editor.apply()
    }

    /**
     * Whether to post a reminder after each payment. The app sets this from
     * its own settings (the payment reminder and the main notifications
     * switch), since the listener runs without the app.
     */
    fun isNotifyEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_NOTIFY, true)

    fun setNotifyEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_NOTIFY, enabled).apply()
    }

    /** Records that [key] was reminded about. False if it already was. */
    @Synchronized
    fun markNotified(context: Context, key: String): Boolean {
        val prefs = prefs(context)
        val notified = JSONArray(prefs.getString(KEY_NOTIFIED, "[]"))
        for (i in 0 until notified.length()) {
            if (notified.optString(i) == key) return false
        }
        notified.put(key)
        val trimmed = JSONArray()
        for (i in maxOf(0, notified.length() - MAX_NOTIFIED) until notified.length()) {
            trimmed.put(notified.get(i))
        }
        prefs.edit().putString(KEY_NOTIFIED, trimmed.toString()).apply()
        return true
    }

    @Synchronized
    fun add(context: Context, key: String, title: String, text: String, postedAt: Long) {
        val prefs = prefs(context)
        val pending = JSONArray(prefs.getString(KEY_PENDING, "[]"))
        pending.put(
            JSONObject()
                .put("key", key)
                .put("title", title)
                .put("text", text)
                .put("postedAt", postedAt)
        )
        // Keep the newest entries if the app has not been opened for a long time.
        val trimmed = JSONArray()
        for (i in maxOf(0, pending.length() - MAX_PENDING) until pending.length()) {
            trimmed.put(pending.get(i))
        }
        prefs.edit().putString(KEY_PENDING, trimmed.toString()).apply()
    }

    /** Returns the waiting notifications and clears them. */
    @Synchronized
    fun drain(context: Context): List<Map<String, Any>> {
        val prefs = prefs(context)
        val pending = JSONArray(prefs.getString(KEY_PENDING, "[]"))
        val result = ArrayList<Map<String, Any>>(pending.length())
        for (i in 0 until pending.length()) {
            val item = pending.getJSONObject(i)
            result.add(
                mapOf(
                    "key" to item.optString("key"),
                    "title" to item.optString("title"),
                    "text" to item.optString("text"),
                    "postedAt" to item.optLong("postedAt"),
                )
            )
        }
        prefs.edit().remove(KEY_PENDING).apply()
        return result
    }
}
