package com.jjclover.smartrelay

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.util.Log

class DefaultSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        val isDeliver = intent.action == Telephony.Sms.Intents.SMS_DELIVER_ACTION
        val appContext = context.applicationContext

        try {
            Log.i(TAG, "Received ${intent.action}; forwarding to Dart SMS handler.")

            if (isDeliver) {
                persistIncomingSms(appContext, intent)
            }

            SmsBackgroundBridge.processIntent(appContext, intent) { success ->
                if (!success) {
                    Log.w(TAG, "Incoming SMS was not fully processed by Dart.")
                }
                finishPendingResult(pendingResult, isDeliver)
            }
            return
        } catch (e: Exception) {
            Log.e(TAG, "Unable to hand incoming SMS to Dart.", e)
            finishPendingResult(pendingResult, isDeliver)
        }
    }

    private fun finishPendingResult(
        pendingResult: BroadcastReceiver.PendingResult,
        isDeliver: Boolean,
    ) {
        Handler(Looper.getMainLooper()).post {
            try {
                if (isDeliver) {
                    pendingResult.resultCode = Telephony.Sms.Intents.RESULT_SMS_HANDLED
                }
            } finally {
                pendingResult.finish()
            }
        }
    }

    private fun persistIncomingSms(context: Context, intent: Intent) {
        try {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isEmpty()) return

            val subscriptionId = intent.getIntExtra("subscription", -1)
            val grouped = messages.groupBy { it.originatingAddress.orEmpty() }

            grouped.forEach { (address, parts) ->
                val body = parts.joinToString(separator = "") { it.messageBody.orEmpty() }
                if (address.isBlank() || body.isBlank()) return@forEach

                val timestamp = parts.first().timestampMillis
                if (isAlreadyStored(context, address, body, timestamp)) return@forEach

                val values = ContentValues().apply {
                    put(Telephony.Sms.ADDRESS, address)
                    put(Telephony.Sms.BODY, body)
                    put(Telephony.Sms.DATE, timestamp)
                    put(Telephony.Sms.READ, 0)
                    put(Telephony.Sms.SEEN, 0)
                    put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
                    if (subscriptionId >= 0) {
                        put(Telephony.Sms.SUBSCRIPTION_ID, subscriptionId)
                    }
                }

                context.contentResolver.insert(Telephony.Sms.Inbox.CONTENT_URI, values)
            }

        } catch (e: SecurityException) {
            Log.w(TAG, "Unable to persist incoming SMS.", e)
        } catch (e: Exception) {
            Log.w(TAG, "Incoming SMS persistence failed.", e)
        }
    }

    private fun isAlreadyStored(
        context: Context,
        address: String,
        body: String,
        timestamp: Long,
    ): Boolean {
        val cursor = context.contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            arrayOf(Telephony.Sms._ID),
            "${Telephony.Sms.ADDRESS} = ? AND ${Telephony.Sms.DATE} = ? AND ${Telephony.Sms.BODY} = ?",
            arrayOf(address, timestamp.toString(), body),
            null,
        )

        cursor.use {
            return it?.moveToFirst() == true
        }
    }

    private companion object {
        const val TAG = "DefaultSmsReceiver"
    }
}
