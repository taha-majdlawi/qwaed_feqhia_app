import 'package:flutter_test/flutter_test.dart';
import 'package:qawaid_fiqhiyya/core/arabic.dart';

void main() {
  group('normalizeArabic', () {
    test('يُسقط التشكيل', () {
      expect(normalizeArabic('الضَّرَرُ يُزَالُ'), 'الضرر يزال');
    });

    test('يُسقط التطويل', () {
      expect(normalizeArabic('الضـــرر'), 'الضرر');
    });

    test('يوحّد صور الألف', () {
      expect(normalizeArabic('أحمد'), normalizeArabic('احمد'));
      expect(normalizeArabic('إبراهيم'), normalizeArabic('ابراهيم'));
      expect(normalizeArabic('آية'), normalizeArabic('ايه'));
    });

    test('يوحّد التاء المربوطة بالهاء والألف المقصورة بالياء', () {
      expect(normalizeArabic('المشقة'), normalizeArabic('المشقه'));
      expect(normalizeArabic('على'), normalizeArabic('علي'));
    });

    test('يوحّد الهمزة على الواو والياء', () {
      expect(normalizeArabic('مسؤول'), normalizeArabic('مسوول'));
      expect(normalizeArabic('مسائل'), normalizeArabic('مسايل'));
    });

    test('يجعل الترقيم والمسافات المتكرّرة فاصلاً واحداً', () {
      expect(
        normalizeArabic('المشقة   تجلب،   التيسير.'),
        'المشقه تجلب التيسير',
      );
    });

    test('لا يترك فاصلاً في الطرفين', () {
      expect(normalizeArabic('  «الضرر يزال»  '), 'الضرر يزال');
    });

    test('نصّ بلا حروف قابلة للبحث يُعطي نصاً فارغاً', () {
      expect(normalizeArabic('... ،،، '), '');
      expect(normalizeArabic(''), '');
    });

    test('البحث عن القاعدتين المذكورتين في ورقة التسليم يطابق النصّ المشكول',
        () {
      const source = 'قاعدة: «الضَّرَرُ يُزَالُ»، وقاعدة «المَشَقَّةُ '
          'تَجْلِبُ التَّيْسِيرَ».';
      final normalized = normalizeArabic(source);
      expect(normalized.contains(normalizeArabic('الضرر يزال')), isTrue);
      expect(
        normalized.contains(normalizeArabic('المشقة تجلب التيسير')),
        isTrue,
      );
    });
  });

  group('NormalizedText.toOriginalRange', () {
    test('يُعيد موضع المطابقة في النص الأصلي المشكول', () {
      const source = 'قاعدة الضَّرَرُ يُزَالُ مشهورة';
      final norm = NormalizedText.of(source);
      final at = norm.value.indexOf('الضرر');
      expect(at, greaterThanOrEqualTo(0));

      final (start, end) = norm.toOriginalRange(at, 'الضرر'.length);
      // المدى في النص الأصلي يبدأ عند الألف ويشمل التشكيل الداخلي.
      expect(source.substring(start, end), startsWith('الضَّرَر'));
      expect(source[start], 'ا');
    });

    test('المدى لكل الكلمات يبقى داخل حدود النص', () {
      const source = 'المَشَقَّةُ تَجْلِبُ التَّيْسِيرَ';
      final norm = NormalizedText.of(source);
      final (start, end) = norm.toOriginalRange(0, norm.value.length);
      expect(start, 0);
      expect(end, lessThanOrEqualTo(source.length));
    });

    test('طول صفري أو نص فارغ لا يرمي', () {
      final norm = NormalizedText.of('الضرر');
      expect(norm.toOriginalRange(0, 0), (0, 0));
      expect(NormalizedText.of('').toOriginalRange(5, 3), (0, 0));
    });

    test('موضع خارج الحدود يُقصَر ولا يرمي', () {
      final norm = NormalizedText.of('الضرر يزال');
      final (start, end) = norm.toOriginalRange(999, 5);
      expect(start, lessThanOrEqualTo(end));
    });
  });

  group('toArabicDigits', () {
    test('يحوّل الأرقام ويترك الحروف', () {
      expect(toArabicDigits('الحلقة 42'), 'الحلقة ٤٢');
      expect(toArabicDigits('1:05'), '١:٠٥');
      expect(toArabicDigits('بلا أرقام'), 'بلا أرقام');
    });
  });

  group('formatDuration', () {
    test('أقل من ساعة: m:ss', () {
      expect(formatDuration(const Duration(minutes: 13, seconds: 42)), '13:42');
      expect(formatDuration(const Duration(seconds: 5)), '0:05');
    });

    test('ساعة أو أكثر: h:mm:ss', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('بالأرقام العربية', () {
      expect(
        formatDuration(const Duration(minutes: 13, seconds: 42),
            arabicDigits: true),
        '١٣:٤٢',
      );
    });
  });

  group('describeDuration', () {
    test('يراعي المثنّى والجمع', () {
      expect(describeDuration(const Duration(seconds: 30)), 'أقل من دقيقة');
      expect(describeDuration(const Duration(minutes: 1)), 'دقيقة');
      expect(describeDuration(const Duration(minutes: 2)), 'دقيقتان');
      expect(describeDuration(const Duration(minutes: 7)), '٧ دقائق');
      expect(describeDuration(const Duration(minutes: 13)), '١٣ دقيقة');
    });
  });

  group('formatBytes', () {
    test('بايت وكيلوبايت وميجابايت', () {
      expect(formatBytes(512), '512 بايت');
      expect(formatBytes(2048), '٢ ك.ب');
      expect(formatBytes(6 * 1024 * 1024), '٦.٠ م.ب');
    });
  });
}
