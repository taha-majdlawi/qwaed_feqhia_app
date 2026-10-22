/// أدوات معالجة النص العربي: التطبيع للبحث وتنسيق الأرقام والأوقات.
library;

const _diacriticRanges = [
  [0x064B, 0x0652],
  [0x0653, 0x0655],
  [0x0670, 0x0670],
  [0x06D6, 0x06ED],
  [0x0640, 0x0640], // التطويل
];

bool _isDiacritic(int c) {
  for (final r in _diacriticRanges) {
    if (c >= r[0] && c <= r[1]) return true;
  }
  return false;
}

bool _isSearchable(int c) =>
    (c >= 0x0621 && c <= 0x064A) || // حروف عربية
    (c >= 0x30 && c <= 0x39) || // أرقام
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A);

int _foldChar(int c) {
  switch (c) {
    case 0x0622: // آ
    case 0x0623: // أ
    case 0x0625: // إ
    case 0x0671: // ٱ
      return 0x0627; // ا
    case 0x0649: // ى
    case 0x0626: // ئ
      return 0x064A; // ي
    case 0x0629: // ة
      return 0x0647; // ه
    case 0x0624: // ؤ
      return 0x0648; // و
    default:
      if (c >= 0x41 && c <= 0x5A) return c + 32; // تصغير اللاتيني
      return c;
  }
}

/// نص مطبّع للبحث مع خريطة تُعيد كل حرف إلى موضعه في النص الأصلي،
/// حتى يمكن تظليل المطابقة على النص المشكول كما هو.
class NormalizedText {
  const NormalizedText(this.value, this.offsets);

  final String value;

  /// `offsets[i]` = موضع الحرف i من `value` داخل النص الأصلي.
  final List<int> offsets;

  /// يحوّل مدى داخل `value` إلى مدى داخل النص الأصلي.
  (int, int) toOriginalRange(int start, int length) {
    if (offsets.isEmpty || length <= 0) return (0, 0);
    final s = offsets[start.clamp(0, offsets.length - 1)];
    final lastIndex = (start + length - 1).clamp(0, offsets.length - 1);
    return (s, offsets[lastIndex] + 1);
  }

  factory NormalizedText.of(String input) {
    final buffer = StringBuffer();
    final offsets = <int>[];
    var pendingSpace = false;

    for (var i = 0; i < input.length; i++) {
      final c = input.codeUnitAt(i);
      if (_isDiacritic(c)) continue;

      if (!_isSearchable(c)) {
        // أي شيء آخر (ترقيم أو مسافة) يصير فاصلاً واحداً.
        if (buffer.isNotEmpty) pendingSpace = true;
        continue;
      }

      if (pendingSpace) {
        buffer.writeCharCode(0x20);
        offsets.add(i);
        pendingSpace = false;
      }
      buffer.writeCharCode(_foldChar(c));
      offsets.add(i);
    }

    return NormalizedText(buffer.toString(), offsets);
  }
}

/// يُرجع صيغة موحّدة من النص تُستخدم في البحث: بلا تشكيل ولا تطويل،
/// مع توحيد الألف والياء والتاء المربوطة والهمزات وإزالة علامات الترقيم.
String normalizeArabic(String input) => NormalizedText.of(input).value;

/// أرقام عربية-هندية للعرض.
const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

String toArabicDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      buffer.write(_arabicDigits[rune - 0x30]);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// تنسيق المدة بصيغة m:ss أو h:mm:ss.
String formatDuration(Duration d, {bool arabicDigits = false}) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  final text = hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
      : '$minutes:${seconds.toString().padLeft(2, '0')}';
  return arabicDigits ? toArabicDigits(text) : text;
}

/// وصف مختصر للمدة بالعربية، مثل «١٣ دقيقة».
String describeDuration(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 1) return 'أقل من دقيقة';
  if (minutes == 1) return 'دقيقة';
  if (minutes == 2) return 'دقيقتان';
  if (minutes <= 10) return '${toArabicDigits('$minutes')} دقائق';
  return '${toArabicDigits('$minutes')} دقيقة';
}

/// حجم الملف بصيغة مقروءة.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes بايت';
  if (bytes < 1024 * 1024) {
    return '${toArabicDigits((bytes / 1024).toStringAsFixed(0))} ك.ب';
  }
  return '${toArabicDigits((bytes / (1024 * 1024)).toStringAsFixed(1))} م.ب';
}
