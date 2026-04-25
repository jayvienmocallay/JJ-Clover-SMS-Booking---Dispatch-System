package com.jjclover.smartrelay

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.telephony.SmsManager

class RespondViaMessageService : Service() {
    private val respondViaMessageAction = "android.intent.action.RESPOND_VIA_MESSAGE"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == respondViaMessageAction) {
            val recipient = intent.data?.schemeSpecificPart
            val message = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()

            if (!recipient.isNullOrBlank() && !message.isNullOrBlank()) {
                SmsManager.getDefault().sendTextMessage(recipient, null, message, null, null)
            }
        }

        stopSelf(startId)
        return START_NOT_STICKY
    }
}
