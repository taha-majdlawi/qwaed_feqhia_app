import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// إذن الإشعارات على أندرويد ١٣+ (POST_NOTIFICATIONS).
///
/// إشعار التحكّم بالصوت — الذي يُبقي التشغيل حيّاً في الخلفية — لا يظهر
/// بغير هذا الإذن، ومنذ أندرويد ١٣ لا يُمنح بمجرّد إعلانه في المانيفست،
/// بل يجب طلبه من المستخدم وقت التشغيل. الطلب يمرّ على قناة أصلية يوفّرها
/// `MainActivity`، فلا حاجة إلى حزمة خارجية.
///
/// على ما قبل أندرويد ١٣ وعلى بقيّة المنصّات: لا شيء يُطلب.
class NotificationPermission {
  NotificationPermission._();

  static const MethodChannel _channel =
      MethodChannel('com.qawaid.fiqhiyya/permissions');

  /// يُطلب الإذن مرّة واحدة في عمر تشغيل التطبيق فقط.
  static bool _asked = false;

  /// آخر نتيجة معروفة للإذن (null = لم يُسأل بعد).
  static bool? _granted;

  static bool? get isGranted => _granted;

  /// يطلب الإذن إن لم يكن ممنوحاً. يُستدعى قبل أوّل تشغيل لحلقة.
  ///
  /// لا يرمي أبداً: تعذُّر الطلب يعني أن الصوت سيعمل بلا إشعار تحكّم،
  /// وهذا لا يستحقّ إفشال التشغيل.
  static Future<bool> ensureGranted() async {
    if (_asked) return _granted ?? false;
    _asked = true;

    if (kIsWeb || !Platform.isAndroid) {
      return _granted = true;
    }

    try {
      final granted =
          await _channel.invokeMethod<bool>('requestNotificationPermission');
      return _granted = granted ?? false;
    } on MissingPluginException {
      // النشاط الأصلي لا يوفّر القناة (نسخة قديمة مثلاً)
      return _granted = false;
    } on PlatformException catch (e) {
      debugPrint('تعذّر طلب إذن الإشعارات: ${e.message}');
      return _granted = false;
    }
  }
}
