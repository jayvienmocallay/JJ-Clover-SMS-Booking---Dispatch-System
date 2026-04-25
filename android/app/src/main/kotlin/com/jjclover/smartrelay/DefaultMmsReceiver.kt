package com.jjclover.smartrelay

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class DefaultMmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Required for Android default SMS app eligibility. JJ Clover only processes SMS commands.
    }
}
