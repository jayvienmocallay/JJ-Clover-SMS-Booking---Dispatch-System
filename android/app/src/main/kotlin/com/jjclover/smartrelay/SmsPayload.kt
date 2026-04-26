package com.jjclover.smartrelay

import android.content.Intent
import java.security.MessageDigest

data class SmsPayload(
    val sourceMessageId: String,
    val sender: String,
    val message: String,
    val timestamp: Long,
    val subscriptionId: Int?,
    val serviceCenterAddress: String?,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "sourceMessageId" to sourceMessageId,
        "sender" to sender,
        "message" to message,
        "timestamp" to timestamp,
        "subscriptionId" to subscriptionId,
        "serviceCenterAddress" to serviceCenterAddress,
    )

    fun writeTo(intent: Intent) {
        intent.putExtra(EXTRA_SOURCE_MESSAGE_ID, sourceMessageId)
        intent.putExtra(EXTRA_SENDER, sender)
        intent.putExtra(EXTRA_MESSAGE, message)
        intent.putExtra(EXTRA_TIMESTAMP, timestamp)
        if (subscriptionId != null) {
            intent.putExtra(EXTRA_SUBSCRIPTION_ID, subscriptionId)
        }
        intent.putExtra(EXTRA_SERVICE_CENTER_ADDRESS, serviceCenterAddress)
    }

    companion object {
        private const val EXTRA_SOURCE_MESSAGE_ID = "sourceMessageId"
        private const val EXTRA_SENDER = "sender"
        private const val EXTRA_MESSAGE = "message"
        private const val EXTRA_TIMESTAMP = "timestamp"
        private const val EXTRA_SUBSCRIPTION_ID = "subscriptionId"
        private const val EXTRA_SERVICE_CENTER_ADDRESS = "serviceCenterAddress"

        fun create(
            sender: String,
            message: String,
            timestamp: Long,
            subscriptionId: Int?,
            serviceCenterAddress: String?,
        ): SmsPayload {
            val sourceMessageId = buildSourceMessageId(
                sender = sender,
                message = message,
                timestamp = timestamp,
                subscriptionId = subscriptionId,
            )
            return SmsPayload(
                sourceMessageId = sourceMessageId,
                sender = sender,
                message = message,
                timestamp = timestamp,
                subscriptionId = subscriptionId,
                serviceCenterAddress = serviceCenterAddress,
            )
        }

        fun fromIntent(intent: Intent): SmsPayload? {
            val sourceMessageId = intent.getStringExtra(EXTRA_SOURCE_MESSAGE_ID)
            val sender = intent.getStringExtra(EXTRA_SENDER)
            val message = intent.getStringExtra(EXTRA_MESSAGE)
            val timestamp = intent.getLongExtra(EXTRA_TIMESTAMP, -1L)
            if (sourceMessageId.isNullOrBlank() || sender.isNullOrBlank() ||
                message.isNullOrBlank() || timestamp < 0
            ) {
                return null
            }

            val subscriptionId = if (intent.hasExtra(EXTRA_SUBSCRIPTION_ID)) {
                intent.getIntExtra(EXTRA_SUBSCRIPTION_ID, -1).takeIf { it >= 0 }
            } else {
                null
            }

            return SmsPayload(
                sourceMessageId = sourceMessageId,
                sender = sender,
                message = message,
                timestamp = timestamp,
                subscriptionId = subscriptionId,
                serviceCenterAddress = intent.getStringExtra(EXTRA_SERVICE_CENTER_ADDRESS),
            )
        }

        private fun buildSourceMessageId(
            sender: String,
            message: String,
            timestamp: Long,
            subscriptionId: Int?,
        ): String {
            val normalizedSender = normalizeSender(sender).ifBlank { sender.trim() }
            val bodyHash = sha256(message)
            return "$normalizedSender|$timestamp|${subscriptionId ?: -1}|$bodyHash"
        }

        private fun normalizeSender(value: String): String {
            val digits = value.replace(Regex("\\D"), "")
            return when {
                digits.length == 12 && digits.startsWith("63") -> "0${digits.substring(2)}"
                digits.length == 10 && digits.startsWith("9") -> "0$digits"
                else -> digits
            }
        }

        private fun sha256(value: String): String {
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(value.toByteArray(Charsets.UTF_8))
            return digest.joinToString(separator = "") { "%02x".format(it.toInt() and 0xff) }
        }
    }
}
