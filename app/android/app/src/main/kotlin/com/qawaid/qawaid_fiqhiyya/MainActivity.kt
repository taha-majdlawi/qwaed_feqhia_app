package com.qawaid.qawaid_fiqhiyya

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * يرث AudioServiceActivity ليعمل التشغيل في الخلفية مع إشعار التحكّم،
 * ويضيف قناة صغيرة لطلب إذن الإشعارات على أندرويد 13 فما فوق.
 */
class MainActivity : AudioServiceActivity() {

    private val channelName = "com.qawaid.fiqhiyya/permissions"
    private val notificationRequestCode = 4201

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotifications" -> result.success(requestNotifications())
                    else -> result.notImplemented()
                }
            }
    }

    /** يُرجع true إن كان الإذن ممنوحاً أصلاً أو غير مطلوب على هذه النسخة. */
    private fun requestNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true

        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED

        if (!granted) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                notificationRequestCode,
            )
        }
        return granted
    }
}
