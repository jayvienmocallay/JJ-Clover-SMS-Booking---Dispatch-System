package com.jjclover.smartrelay

import android.Manifest
import android.app.Activity
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicInteger

object NativeSmsSender {
    private const val CHANNEL_NAME = "com.jjclover.smartrelay/native_sms"
    private const val TAG = "NativeSmsSender"
    private const val METHOD_STATUS_CHANGED = "smsStatusChanged"
    private const val ACTION_SMS_SENT = "com.jjclover.smartrelay.SMS_SENT"
    private const val ACTION_SMS_DELIVERED = "com.jjclover.smartrelay.SMS_DELIVERED"
    private const val EXTRA_SOURCE_MESSAGE_ID = "sourceMessageId"
    private const val EXTRA_PART_INDEX = "partIndex"
    private const val EXTRA_PART_COUNT = "partCount"

    private val requestCodes = AtomicInteger(410900)
    private val pendingStatusEvents = mutableListOf<Map<String, Any?>>()
    private var statusChannel: MethodChannel? = null
    private var isDartStatusReady = false

    fun register(binaryMessenger: BinaryMessenger, context: Context) {
        val appContext = context.applicationContext
        val channel = MethodChannel(binaryMessenger, CHANNEL_NAME)
        synchronized(this) {
            statusChannel = channel
            isDartStatusReady = false
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val recipient = call.argument<String>("to")
                    val message = call.argument<String>("message")
                    val sourceMessageId = call.argument<String>("sourceMessageId")
                    if (recipient.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error(
                            "invalid_sms_request",
                            "SMS recipient and message are required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        result.success(sendSms(appContext, recipient, message, sourceMessageId))
                    } catch (e: SecurityException) {
                        result.success(
                            statusResult(
                                "failed",
                                "send_sms_permission_denied",
                                "SEND_SMS permission is not granted.",
                            ),
                        )
                    } catch (e: Exception) {
                        result.success(statusResult("failed", "sms_send_failed", e.message))
                    }
                }
                "smsStatusListenerReady" -> {
                    synchronized(this) {
                        isDartStatusReady = true
                    }
                    drainStatusEvents()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun sendSms(
        context: Context,
        recipient: String,
        message: String,
        sourceMessageId: String?,
    ): Map<String, Any?> {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            context.checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("SEND_SMS permission is not granted.")
        }

        val smsManager = SmsManager.getDefault()
        val parts = smsManager.divideMessage(message)
        val hasTracking = !sourceMessageId.isNullOrBlank()
        val sentIntents = if (hasTracking) {
            buildStatusIntents(context, ACTION_SMS_SENT, sourceMessageId!!, parts.size)
        } else {
            null
        }
        val deliveryIntents = if (hasTracking) {
            buildStatusIntents(context, ACTION_SMS_DELIVERED, sourceMessageId!!, parts.size)
        } else {
            null
        }

        if (parts.size > 1) {
            smsManager.sendMultipartTextMessage(
                recipient,
                null,
                parts,
                sentIntents,
                deliveryIntents,
            )
        } else {
            smsManager.sendTextMessage(
                recipient,
                null,
                message,
                sentIntents?.firstOrNull(),
                deliveryIntents?.firstOrNull(),
            )
        }
        return statusResult(if (hasTracking) "queued" else "sent")
    }

    private fun buildStatusIntents(
        context: Context,
        action: String,
        sourceMessageId: String,
        partCount: Int,
    ): ArrayList<PendingIntent> {
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }

        return ArrayList(
            (0 until partCount).map { index ->
                val intent = Intent(context, SmsStatusReceiver::class.java).apply {
                    this.action = action
                    putExtra(EXTRA_SOURCE_MESSAGE_ID, sourceMessageId)
                    putExtra(EXTRA_PART_INDEX, index)
                    putExtra(EXTRA_PART_COUNT, partCount)
                }
                PendingIntent.getBroadcast(
                    context,
                    requestCodes.incrementAndGet(),
                    intent,
                    flags,
                )
            },
        )
    }

    fun handleStatusBroadcast(intent: Intent, resultCode: Int) {
        val sourceMessageId = intent.getStringExtra(EXTRA_SOURCE_MESSAGE_ID)
        if (sourceMessageId.isNullOrBlank()) return

        val status = when (intent.action) {
            ACTION_SMS_SENT -> if (resultCode == Activity.RESULT_OK) "sent" else "failed"
            ACTION_SMS_DELIVERED -> if (resultCode == Activity.RESULT_OK) "delivered" else "failed"
            else -> return
        }

        emitStatusEvent(
            mapOf(
                "sourceMessageId" to sourceMessageId,
                "status" to status,
                "errorCode" to errorCodeFor(resultCode),
                "errorMessage" to errorMessageFor(resultCode),
                "partIndex" to intent.getIntExtra(EXTRA_PART_INDEX, 0),
                "partCount" to intent.getIntExtra(EXTRA_PART_COUNT, 1),
            ),
        )
    }

    private fun emitStatusEvent(event: Map<String, Any?>) {
        val channel = synchronized(this) {
            if (statusChannel == null || !isDartStatusReady) {
                bufferStatusEventLocked(event)
                null
            } else {
                statusChannel
            }
        }

        channel?.invokeMethod(
            METHOD_STATUS_CHANGED,
            event,
            object : MethodChannel.Result {
                override fun success(result: Any?) = Unit

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.w(TAG, "Dart rejected SMS status update: $errorCode $errorMessage")
                    bufferStatusEvent(event)
                }

                override fun notImplemented() {
                    Log.w(TAG, "Dart SMS status callback is not implemented.")
                    bufferStatusEvent(event)
                }
            },
        )
    }

    private fun drainStatusEvents() {
        val events = synchronized(this) {
            val copy = pendingStatusEvents.toList()
            pendingStatusEvents.clear()
            copy
        }
        events.forEach { event ->
            try {
                emitStatusEvent(event)
            } catch (e: Exception) {
                Log.w(TAG, "Unable to emit buffered SMS status.", e)
                bufferStatusEvent(event)
            }
        }
    }

    private fun bufferStatusEvent(event: Map<String, Any?>) {
        synchronized(this) {
            bufferStatusEventLocked(event)
        }
    }

    private fun bufferStatusEventLocked(event: Map<String, Any?>) {
        pendingStatusEvents.add(event)
        isDartStatusReady = false
    }

    private fun statusResult(
        status: String,
        errorCode: String? = null,
        errorMessage: String? = null,
    ): Map<String, Any?> = mapOf(
        "status" to status,
        "errorCode" to errorCode,
        "errorMessage" to errorMessage,
    )

    private fun errorCodeFor(resultCode: Int): String? {
        return when (resultCode) {
            Activity.RESULT_OK -> null
            SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "generic_failure"
            SmsManager.RESULT_ERROR_NO_SERVICE -> "no_service"
            SmsManager.RESULT_ERROR_NULL_PDU -> "null_pdu"
            SmsManager.RESULT_ERROR_RADIO_OFF -> "radio_off"
            Activity.RESULT_CANCELED -> "canceled"
            else -> "result_$resultCode"
        }
    }

    private fun errorMessageFor(resultCode: Int): String? {
        return when (errorCodeFor(resultCode)) {
            null -> null
            "generic_failure" -> "Generic SMS send failure."
            "no_service" -> "No SMS service is available."
            "null_pdu" -> "SMS PDU was null."
            "radio_off" -> "Cellular radio is off."
            "canceled" -> "SMS status callback was canceled."
            else -> "SMS status callback returned $resultCode."
        }
    }
}
