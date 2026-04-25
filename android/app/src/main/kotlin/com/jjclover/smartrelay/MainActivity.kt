package com.jjclover.smartrelay

import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.jjclover.smartrelay/default_sms"
    private val requestDefaultSmsCode = 4107
    private var pendingDefaultSmsResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDefaultSmsApp" -> result.success(isDefaultSmsApp())
                "requestDefaultSmsApp" -> requestDefaultSmsApp(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun isDefaultSmsApp(): Boolean {
        return Telephony.Sms.getDefaultSmsPackage(this) == packageName
    }

    private fun requestDefaultSmsApp(result: MethodChannel.Result) {
        if (isDefaultSmsApp()) {
            result.success(true)
            return
        }

        if (pendingDefaultSmsResult != null) {
            result.error("request_in_progress", "A default SMS request is already open.", null)
            return
        }

        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            if (roleManager == null || !roleManager.isRoleAvailable(RoleManager.ROLE_SMS)) {
                result.error("role_unavailable", "Default SMS role is not available on this device.", null)
                return
            }
            roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
        } else {
            Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT).apply {
                putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
            }
        }

        pendingDefaultSmsResult = result
        startActivityForResult(intent, requestDefaultSmsCode)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == requestDefaultSmsCode) {
            pendingDefaultSmsResult?.success(isDefaultSmsApp())
            pendingDefaultSmsResult = null
        }
    }
}
