package com.jjclover.smartrelay

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class SmsStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        NativeSmsSender.handleStatusBroadcast(intent, resultCode)
    }
}
