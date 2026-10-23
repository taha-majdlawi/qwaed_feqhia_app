import 'package:flutter_test/flutter_test.dart';
import 'package:qawaid_fiqhiyya/core/arabic.dart';

void main() {
  group('normalizeArabic', () {
    test('يحذف التشكيل', () {
      expect(normalizeArabic('الضَّرَرُ يُزَالُ'), 'الضرر يزال');
      expect(normalizeArabic('اليَقِينُ لا يَزُولُ بِالشَّكِّ'),
          'اليقين لا يزول بالشك');
    });

    test('يوحّد صور الألف', () {
      expect(normalizeArabic('أحمد'), normalizeArabic('احمد'));
      expect(normalizeArabic('إسلام'), normalizeArabic('اسلام'));
      expect(normalizeArabic('آية'), normalizeArabic('ايه'));
    });

    test('يوحّد الياء والتاء المربوطة والهمزات', () {
      expect(normalizeArabic('على'), normalizeArabic('علي'));
      expect(normalizeArabic('قاعدة'), normalizeArabic('قاعده'));
      expect(normalizeArabic('مسؤول'), normalizeArabic('مسوول'));
      expect(normalizeArabic('قائل'), normalizeArabic('قايل'));
    });

    test('يحذف التطويل وعلامات الترقيم ويضغط المسافات', () {
      expect(normalizeArabic('الــــعلم'), 'العلم');
      expect(normalizeArabic('قال: «الأمور بمقاصدها».'), 'قال الامور بمقاصدها');
      expect(normalizeArabic('  كلمتان   هنا  '), 'كلمتان هنا');
    });

    test('النص الفارغ أو بلا حروف يعطي نصاً فارغاً', () {
      expect(normalizeArabic(''), '');
      expect(normalizeArabic('… «» .'), '');
    });
  });

  group('NormalizedText.toOriginalRange', () {
    test('يعيد موضع المطابقة في النص الأصلي المشكول', () {
      const original = 'مثلاً قاعدة «الضَّرَرُ يُزَالُ» مخصِّصة';
      final norm = NormalizedText.of(original);

      final at = norm.value.indexOf(normalizeArabic('الضرر يزال'));
      expect(at, isNonNegative);

      final (start, end) =
          norm.toOriginalRange(at, normalizeArabic('الضرر يزال').length);
      final slice = original.substring(start, end);

      // المقطع المستخرج هو نفسه بعد التطبيع
      expect(normalizeArabic(slice), 'الضرر يزال');
      // وهو مشكول كما في الأصل
      expect(slice.contains('َ') || slice.contains('ُ'), isTrue);
    });

    test('يعمل عند بداية النص ونهايته', () {
      const original = 'العِلْمُ نورٌ';
      final norm = NormalizedText.of(original);

      final (s1, e1) = norm.toOriginalRange(0, normalizeArabic('العلم').length);
      expect(normalizeArabic(original.substring(s1, e1)), 'العلم');

      final at = norm.value.indexOf('نور');
      final (s2, e2) = norm.toOriginalRange(at, 3);
      expect(normalizeArabic(original.substring(s2, e2)), 'نور');
    });

    test('مدى فارغ لا يرمي استثناء', () {
      final norm = NormalizedText.of('نص');
      expect(norm.toOriginalRange(0, 0), (0, 0));
    });
  });

  group('toArabicDigits و digits', () {
    test('يحوّل الأرقام فقط', () {
      expect(toArabicDigits('الحلقة 12'), 'الحلقة ١٢');
      expect(toArabicDigits('0123456789'), '٠١٢٣٤٥٦٧٨٩');
    });

    test('digits يحترم الخيار', () {
      expect(digits('الحلقة 7', arabic: true), 'الحلقة ٧');
      expect(digits('الحلقة 7', arabic: false), 'الحلقة 7');
    });
  });

  group('formatDuration', () {
    test('دقائق وثوانٍ', () {
      expect(formatDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
      expect(formatDuration(Duration.zero), '0:00');
    });

    test('ساعات', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 5)),
        '1:02:05',
      );
    });

    test('بأرقام عربية', () {
      expect(
        formatDuration(const Duration(minutes: 13, seconds: 42),
            arabicDigits: true),
        '١٣:٤٢',
      );
    });
  });

  group('describeDuration', () {
    test('صيغ الجمع العربية', () {
      expect(describeDuration(const Duration(seconds: 30)), 'أقل من دقيقة');
      expect(describeDuration(const Duration(minutes: 1)), 'دقيقة');
      expect(describeDuration(const Duration(minutes: 2)), 'دقيقتان');
      expect(describeDuration(const Duration(minutes: 5)), '٥ دقائق');
      expect(describeDuration(const Duration(minutes: 13)), '١٣ دقيقة');
    });

    test('يحترم خيار الأرقام', () {
      expect(
        describeDuration(const Duration(minutes: 13), arabicDigits: false),
        '13 دقيقة',
      );
    });
  });

  group('formatBytes', () {
    test('وحدات مقروءة', () {
      expect(formatBytes(512), '512 بايت');
      expect(formatBytes(2048), '٢ ك.ب');
      expect(formatBytes(6 * 1024 * 1024), '٦٫٠ م.ب'.replaceAll('٫', '.'));
    });
  });
}
