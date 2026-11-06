import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// إبقاء الشاشة مضاءة أثناء متابعة النصّ مع الصوت.
///
/// من يقرأ النصّ مع الشيخ لا يلمس الشاشة، فتنطفئ عليه في منتصف الحلقة.
/// الضبط يمرّ على قناة `MainActivity` نفسها التي تُطلب بها الأذونات،
/// وتضع `FLAG_KEEP_SCREEN_ON` على نافذة النشاط — بلا حزمة خارجية.
///
/// على غير أندرويد: لا شيء يحدث.
class ScreenAwake {
  ScreenAwake._();

  static const MethodChannel _channel =
      MethodChannel('com.qawaid.fiqhiyya/permissions');

  /// آخر حالة أُرسلت، كي لا نعبر القناة في كل إعادة بناء.
  static bool _current = false;

  static bool get isOn => _current;

  /// يضبط الحالة إن تغيّرت فقط. لا يرمي أبداً: تعذُّر الضبط يعني أن الشاشة
  /// تنطفئ كالمعتاد، وهذا لا يستحقّ إفشال التشغيل.
  static Future<void> set(bool on) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (on == _current) return;
    _current = on;
    try {
      await _channel.invokeMethod<void>('setKeepAwake', {'on': on});
    } on MissingPluginException {
      // النشاط الأصلي لا يوفّر القناة (نسخة قديمة مثلاً)
    } on PlatformException catch (e) {
      debugPrint('تعذّر ضبط إبقاء الشاشة مضاءة: ${e.message}');
    }
  }
}
