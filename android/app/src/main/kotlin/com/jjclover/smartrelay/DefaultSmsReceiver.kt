package com.jjclover.smartrelay

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import java.util.concurrent.Executors

class DefaultSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        val isDeliver = intent.action == Telephony.Sms.Intents.SMS_DELIVER_ACTION
        val appContext = context.applicationContext

        executor.execute {
            try {
                Log.i(TAG, "Received ${intent.action}; enqueueing SMS processing.")

                val payloads = buildPayloads(intent)
                if (isDeliver) {
                    persistIncomingSms(appContext, payloads)
                }

                payloads.forEach { payload ->
                    val started = SmsProcessingService.enqueue(appContext, payload)
                    if (!started) {
                        Log.w(TAG, "Falling back to direct Dart bridge processing.")
                        SmsBackgroundBridge.processPayload(appContext, payload) { success ->
                            if (!success) {
                                Log.w(TAG, "Fallback SMS processing failed.")
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Unable to hand incoming SMS to processing service.", e)
            } finally {
                finishPendingResult(pendingResult, isDeliver)
            }
        }
    }

    private fun finishPendingResult(
        pendingResult: BroadcastReceiver.PendingResult,
        isDeliver: Boolean,
    ) {
        try {
            if (isDeliver) {
                pendingResult.resultCode = Telephony.Sms.Intents.RESULT_SMS_HANDLED
            }
        } finally {
            pendingResult.finish()
        }
    }

    private fun buildPayloads(intent: Intent): List<SmsPayload> {
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return emptyList()

        val subscriptionId = extractSubscriptionId(intent)
        return messages
            .groupBy { message ->
                listOf(
                    message.originatingAddress.orEmpty(),
                    message.timestampMillis,
                    message.indexOnIcc,
                )
            }
            .mapNotNull { (_, parts) ->
                val sortedParts = parts.sortedBy { it.indexOnIcc }
                val first = sortedParts.first()
                val sender = first.originatingAddress.orEmpty()
                val body = sortedParts.joinToString(separator = "") { it.messageBody.orEmpty() }
                if (sender.isBlank() || body.isBlank()) {
                    null
                } else {
                    SmsPayload.create(
                        sender = sender,
                        message = body,
                        timestamp = first.timestampMillis,
                        subscriptionId = subscriptionId,
                        serviceCenterAddress = first.serviceCenterAddress,
                    )
                }
            }
    }

    private fun extractSubscriptionId(intent: Intent): Int? {
        val candidates = listOf(
            "subscription",
            "subscriptionId",
            "android.telephony.extra.SUBSCRIPTION_INDEX",
        )
        for (key in candidates) {
            if (intent.hasExtra(key)) {
                val value = intent.getIntExtra(key, -1)
                if (value >= 0) return value
            }
        }
        return null
    }

    private fun persistIncomingSms(context: Context, payloads: List<SmsPayload>) {
        try {
            payloads.forEach { payload ->
                if (isAlreadyStored(context, payload.sender, payload.message, payload.timestamp)) {
                    return@forEach
                }

                val values = ContentValues().apply {
                    put(Telephony.Sms.ADDRESS, payload.sender)
                    put(Telephony.Sms.BODY, payload.message)
                    put(Telephony.Sms.DATE, payload.timestamp)
                    put(Telephony.Sms.READ, 0)
                    put(Telephony.Sms.SEEN, 0)
                    put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
                    payload.subscriptionId?.let {
                        put(Telephony.Sms.SUBSCRIPTION_ID, it)
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
        val executor = Executors.newSingleThreadExecutor()
    }
}
