package com.jjclover.smartrelay

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object NativeSmsSender {
    private const val CHANNEL_NAME = "com.jjclover.smartrelay/native_sms"

    fun register(binaryMessenger: BinaryMessenger, context: Context) {
        val appContext = context.applicationContext
        MethodChannel(binaryMessenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val recipient = call.argument<String>("to")
                    val message = call.argument<String>("message")
                    if (recipient.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error(
                            "invalid_sms_request",
                            "SMS recipient and message are required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        sendSms(appContext, recipient, message)
                        result.success(null)
                    } catch (e: SecurityException) {
                        result.error(
                            "send_sms_permission_denied",
                            "SEND_SMS permission is not granted.",
                            e.message,
                        )
                    } catch (e: Exception) {
                        result.error("sms_send_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun sendSms(context: Context, recipient: String, message: String) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            context.checkSelfPermission(Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED
        ) {
            throw SecurityException("SEND_SMS permission is not granted.")
        }

        val smsManager = SmsManager.getDefault()
        val parts = smsManager.divideMessage(message)
        if (parts.size > 1) {
            smsManager.sendMultipartTextMessage(recipient, null, parts, null, null)
        } else {
            smsManager.sendTextMessage(recipient, null, message, null, null)
        }
    }
}
