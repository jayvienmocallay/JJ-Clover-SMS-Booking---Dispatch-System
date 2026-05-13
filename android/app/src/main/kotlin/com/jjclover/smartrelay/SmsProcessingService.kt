package com.jjclover.smartrelay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

class SmsProcessingService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTimeout(startId: Int, fgsType: Int) {
        Log.w(TAG, "Foreground SMS processing timed out; stopping service.")
        stopSelf(startId)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val payload = intent?.let { SmsPayload.fromIntent(it) }
        if (payload == null) {
            Log.w(TAG, "Started without a valid SMS payload.")
            stopSelf(startId)
            return START_NOT_STICKY
        }

        try {
            startSmsForeground()
        } catch (e: Exception) {
            Log.w(TAG, "Unable to enter foreground SMS processing mode.", e)
        }

        Log.i(TAG, "Processing SMS payload ${payload.sourceMessageId}.")
        SmsBackgroundBridge.processPayload(applicationContext, payload) { success ->
            if (!success) {
                Log.w(TAG, "SMS payload was not fully processed by Dart.")
            }
            stopSelf(startId)
        }

        return START_NOT_STICKY
    }

    private fun startSmsForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SHORT_SERVICE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "SMS processing",
                NotificationManager.IMPORTANCE_LOW,
            )
            manager.createNotificationChannel(channel)
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("JJ Clover")
            .setContentText("Processing incoming SMS")
            .setOngoing(false)
            .build()
    }

    companion object {
        private const val TAG = "SmsProcessingService"
        private const val CHANNEL_ID = "sms_processing"
        private const val NOTIFICATION_ID = 4108

        fun enqueue(context: Context, payload: SmsPayload): Boolean {
            val intent = Intent(context, SmsProcessingService::class.java).also {
                payload.writeTo(it)
            }

            return try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                true
            } catch (e: Exception) {
                Log.w(TAG, "Unable to start SMS processing service.", e)
                false
            }
        }
    }
}
