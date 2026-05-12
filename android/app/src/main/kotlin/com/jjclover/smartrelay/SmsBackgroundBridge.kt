package com.jjclover.smartrelay

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

object SmsBackgroundBridge : MethodChannel.MethodCallHandler {
    private const val TAG = "SmsBackgroundBridge"
    private const val CHANNEL_NAME = "com.jjclover.smartrelay/sms_background"
    private const val DART_ENTRYPOINT_LIBRARY =
        "package:jj_clover_sms/data/services/sms_background_service.dart"
    private const val METHOD_INITIALIZED = "initialized"
    private const val METHOD_PROCESS_SMS = "processSms"
    private const val STARTUP_TIMEOUT_MS = 20_000L
    private const val PROCESS_TIMEOUT_MS = 25_000L

    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingTasks = mutableListOf<SmsTask>()

    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null
    private var isStarting = false
    private var isReady = false

    fun processIntent(context: Context, intent: Intent, onComplete: (Boolean) -> Unit) {
        val payloads = try {
            buildPayloads(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Unable to read SMS broadcast.", e)
            onComplete(false)
            return
        }

        processPayloads(context, payloads, onComplete)
    }

    fun processPayload(context: Context, payload: SmsPayload, onComplete: (Boolean) -> Unit) {
        processPayloads(context, listOf(payload), onComplete)
    }

    private fun processPayloads(
        context: Context,
        payloads: List<SmsPayload>,
        onComplete: (Boolean) -> Unit,
    ) {
        val appContext = context.applicationContext
        if (payloads.isEmpty()) {
            onComplete(false)
            return
        }

        val tasks = buildTasks(payloads, onComplete)
        mainHandler.post {
            tasks.forEach { task ->
                pendingTasks.add(task)
                scheduleStartupTimeout(task)
            }

            try {
                ensureEngine(appContext)
                drainQueue()
            } catch (e: Exception) {
                Log.e(TAG, "Unable to start Dart SMS isolate.", e)
                tasks.forEach { task ->
                    pendingTasks.remove(task)
                    cancelStartupTimeout(task)
                    task.complete(false)
                }
                resetEngine()
            }
        }
    }

    private fun buildPayloads(intent: Intent): List<SmsPayload> {
        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isEmpty()) return emptyList()

        val subscriptionId = extractSubscriptionId(intent)
        return messages
            .groupBy { it.originatingAddress.orEmpty() }
            .mapNotNull { (sender, parts) ->
                val body = parts.joinToString(separator = "") { it.messageBody.orEmpty() }
                if (sender.isBlank() || body.isBlank()) {
                    null
                } else {
                    val first = parts.first()
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

    private fun buildTasks(
        payloads: List<SmsPayload>,
        onComplete: (Boolean) -> Unit,
    ): List<SmsTask> {
        if (payloads.isEmpty()) return emptyList()

        var remaining = payloads.size
        var allSucceeded = true

        fun completeOne(success: Boolean) {
            if (!success) {
                allSucceeded = false
            }
            remaining -= 1
            if (remaining == 0) {
                onComplete(allSucceeded)
            }
        }

        return payloads.map { SmsTask(payload = it, onComplete = ::completeOne) }
    }

    private fun ensureEngine(context: Context) {
        if (flutterEngine != null || isStarting) return

        isStarting = true
        isReady = false

        val flutterLoader = FlutterInjector.instance().flutterLoader()
        flutterLoader.startInitialization(context)
        flutterLoader.ensureInitializationComplete(context, null)

        val engine = FlutterEngine(context)
        NativeSmsSender.register(engine.dartExecutor.binaryMessenger, context)
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)

        flutterEngine = engine
        methodChannel = channel

        val entrypoint = DartExecutor.DartEntrypoint(
            flutterLoader.findAppBundlePath(),
            DART_ENTRYPOINT_LIBRARY,
            "smsNativeBackgroundMain",
        )
        engine.dartExecutor.executeDartEntrypoint(entrypoint)
    }

    private fun scheduleStartupTimeout(task: SmsTask) {
        val timeout = Runnable {
            if (pendingTasks.remove(task)) {
                Log.w(TAG, "Timed out waiting for Dart SMS isolate.")
                task.complete(false)
            }
            if (pendingTasks.isEmpty() && !isReady) {
                resetEngine()
            }
        }
        task.startupTimeout = timeout
        mainHandler.postDelayed(timeout, STARTUP_TIMEOUT_MS)
    }

    private fun cancelStartupTimeout(task: SmsTask) {
        task.startupTimeout?.let { mainHandler.removeCallbacks(it) }
        task.startupTimeout = null
    }

    private fun drainQueue() {
        val channel = methodChannel ?: return
        if (!isReady) return

        val tasks = pendingTasks.toList()
        pendingTasks.clear()
        tasks.forEach { task ->
            cancelStartupTimeout(task)
            dispatch(channel, task)
        }
    }

    private fun dispatch(channel: MethodChannel, task: SmsTask) {
        val timeout = Runnable {
            Log.w(TAG, "Timed out processing SMS from ${task.payload.sender}.")
            task.complete(false)
        }
        task.processTimeout = timeout
        mainHandler.postDelayed(timeout, PROCESS_TIMEOUT_MS)

        channel.invokeMethod(
            METHOD_PROCESS_SMS,
            task.payload.toMap(),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    completeProcessing(task, true)
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "Dart SMS processing failed: $errorCode $errorMessage")
                    completeProcessing(task, false)
                }

                override fun notImplemented() {
                    Log.e(TAG, "Dart SMS processing method is not implemented.")
                    completeProcessing(task, false)
                }
            },
        )
    }

    private fun completeProcessing(task: SmsTask, success: Boolean) {
        task.processTimeout?.let { mainHandler.removeCallbacks(it) }
        task.processTimeout = null
        task.complete(success)
        if (success) {
            MainActivity.notifySmsDataChanged()
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            METHOD_INITIALIZED -> {
                isStarting = false
                isReady = true
                drainQueue()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun resetEngine() {
        methodChannel?.setMethodCallHandler(null)
        flutterEngine?.destroy()
        methodChannel = null
        flutterEngine = null
        isStarting = false
        isReady = false
    }

    private class SmsTask(
        val payload: SmsPayload,
        private val onComplete: (Boolean) -> Unit,
    ) {
        var startupTimeout: Runnable? = null
        var processTimeout: Runnable? = null
        private val completed = AtomicBoolean(false)

        fun complete(success: Boolean) {
            if (completed.compareAndSet(false, true)) {
                onComplete(success)
            }
        }
    }
}
