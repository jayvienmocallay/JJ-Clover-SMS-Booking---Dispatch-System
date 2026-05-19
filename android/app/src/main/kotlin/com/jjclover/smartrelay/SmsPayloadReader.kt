package com.jjclover.smartrelay

import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage

object SmsPayloadReader {
    fun fromIntent(intent: Intent): List<SmsPayload> {
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return emptyList()

        val subscriptionId = extractSubscriptionId(intent)
        return messages
            .mapIndexed { index, message -> IndexedSmsPart(index, message) }
            .groupBy { part ->
                val message = part.message
                listOf(
                    message.originatingAddress.orEmpty(),
                    message.timestampMillis,
                    subscriptionId ?: -1,
                )
            }
            .mapNotNull { (_, parts) ->
                val sortedParts = parts.sortedWith(
                    compareBy<IndexedSmsPart> {
                        it.message.indexOnIcc.takeIf { index -> index >= 0 } ?: Int.MAX_VALUE
                    }.thenBy { it.index },
                )
                val first = sortedParts.first().message
                val sender = first.originatingAddress.orEmpty()
                val body = sortedParts.joinToString(separator = "") {
                    it.message.messageBody.orEmpty()
                }
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
}

private data class IndexedSmsPart(
    val index: Int,
    val message: SmsMessage,
)
