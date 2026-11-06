package com.qawaid.qawaid_fiqhiyya

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * النشاط الرئيسي.
 *
 * يمتدّ [AudioServiceActivity] — وهو شرط just_audio_background كي يبقى
 * التشغيل حيّاً في الخلفية مع إشعار التحكّم.
 *
 * ويوفّر قناة `com.qawaid.fiqhiyya/permissions` لطلب إذن الإشعارات
 * (POST_NOTIFICATIONS) وقت التشغيل على أندرويد ١٣+، فمنذ تلك النسخة لا
 * يكفي إعلان الإذن في المانيفست، وبدونه لا يظهر إشعار التحكّم بالصوت.
 */
class MainActivity : AudioServiceActivity() {

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestNotificationPermission" -> requestNotificationPermission(result)
                    "setKeepAwake" -> {
                        setKeepAwake(call.argument<Boolean>("on") ?: false)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * إبقاء الشاشة مضاءة ما دام الصوت يعمل في شاشة الاستماع.
     * FLAG_KEEP_SCREEN_ON علمٌ على النافذة، يرفعه النظام وحده عند الخروج،
     * فلا حاجة إلى حزمة wakelock ولا إلى إذن.
     */
    private fun setKeepAwake(on: Boolean) {
        runOnUiThread {
            if (on) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    /** يُرجع true إن كان الإذن ممنوحاً (أو غير مطلوب في هذه النسخة). */
    private fun requestNotificationPermission(result: MethodChannel.Result) {
        // ما قبل أندرويد ١٣: الإذن ممنوح بمجرّد إعلانه.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        // طلب سابق ما زال معلّقاً: لا تفتح نافذتين.
        if (pendingResult != null) {
            result.success(false)
            return
        }
        pendingResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_CODE) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingResult?.success(granted)
        pendingResult = null
    }

    companion object {
        private const val CHANNEL = "com.qawaid.fiqhiyya/permissions"
        private const val REQUEST_CODE = 7341
    }
}
