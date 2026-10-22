import 'package:flutter_test/flutter_test.dart';
import 'package:qawaid_fiqhiyya/models/episode.dart';

Paragraph _p(int index, double start, double end, [String text = 'نص']) =>
    Paragraph(index: index, start: start, end: end, text: text);

/// نصّ موقوت مماثل لِما في assets/data/sync/epXX.json: فقرات متلاحقة مرتّبة.
EpisodeTranscript _transcript(List<Paragraph> paragraphs) =>
    EpisodeTranscript(id: 'ep01', paragraphs: paragraphs);

void main() {
  group('EpisodeTranscript.indexAt', () {
    final t = _transcript([
      _p(1, 0, 18),
      _p(2, 18, 42.5),
      _p(3, 42.5, 60),
      _p(4, 60, 95.25),
    ]);

    test('داخل كل فقرة يُعيد موضعها في القائمة (صفري الأساس)', () {
      expect(t.indexAt(0), 0);
      expect(t.indexAt(9), 0);
      expect(t.indexAt(18), 1);
      expect(t.indexAt(42), 1);
      expect(t.indexAt(42.5), 2);
      expect(t.indexAt(59.999), 2);
      expect(t.indexAt(60), 3);
      expect(t.indexAt(95), 3);
    });

    test('الحدّ الأدنى شامل والأعلى غير شامل', () {
      // start شامل، end يخصّ الفقرة التالية.
      expect(t.indexAt(18), 1);
      expect(t.indexAt(17.999), 0);
    });

    test('قبل أوّل فقرة يُعيد الأولى', () {
      expect(t.indexAt(-5), 0);
    });

    test('بعد آخر فقرة يُعيد الأخيرة', () {
      expect(t.indexAt(1000), 3);
    });

    test('نصّ بلا فقرات يُعيد -1', () {
      expect(_transcript(const []).indexAt(10), -1);
    });

    test('فجوة بين فقرتين تُنسب إلى الفقرة السابقة', () {
      final gapped = _transcript([_p(1, 0, 10), _p(2, 20, 30)]);
      expect(gapped.indexAt(15), 0);
    });

    test('البحث الثنائي يوافق البحث الخطّي على كل الحدود', () {
      final many = _transcript(
        List.generate(200, (i) => _p(i + 1, i * 7.5, (i + 1) * 7.5)),
      );
      int linear(double s) {
        for (var i = 0; i < many.paragraphs.length; i++) {
          if (many.paragraphs[i].contains(s)) return i;
        }
        return s < many.paragraphs.first.start
            ? 0
            : many.paragraphs.length - 1;
      }

      for (var i = 0; i < many.paragraphs.length; i++) {
        final p = many.paragraphs[i];
        for (final s in [p.start, p.start + 0.001, p.end - 0.001]) {
          expect(many.indexAt(s), linear(s), reason: 'عند الثانية $s');
        }
      }
    });
  });

  group('Paragraph', () {
    test('contains شامل للبداية غير شامل للنهاية', () {
      final p = _p(1, 10, 20);
      expect(p.contains(10), isTrue);
      expect(p.contains(19.999), isTrue);
      expect(p.contains(20), isFalse);
      expect(p.contains(9.999), isFalse);
    });

    test('تحويل الثواني إلى Duration بتقريب الملّي ثانية', () {
      final p = _p(1, 42.5, 60.25);
      expect(p.startObject, const Duration(milliseconds: 42500));
      expect(p.endObject, const Duration(milliseconds: 60250));
    });

    test('fromJson يقصّ النص ويبني النسخة المطبّعة', () {
      final p = Paragraph.fromJson({
        'index': 3,
        'start': 1,
        'end': 2.5,
        'text': '  الضَّرَرُ يُزَالُ  ',
      });
      expect(p.index, 3);
      expect(p.text, 'الضَّرَرُ يُزَالُ');
      expect(p.normalized, 'الضرر يزال');
    });
  });

  group('Episode', () {
    final json = {
      'id': 'ep01',
      'number': 1,
      'title': 'القواعد الفقهية – الحلقة 1',
      'duration': 822.3,
      'audio': 'audio/ep01.m4a',
      'text': 'text/ep01.txt',
      'sync': 'sync/ep01.json',
      'paragraphCount': 23,
    };

    test('fromJson يقرأ كل الحقول كما في episodes.json', () {
      final e = Episode.fromJson(json);
      expect(e.id, 'ep01');
      expect(e.number, 1);
      expect(e.duration, 822.3);
      expect(e.audioPath, 'audio/ep01.m4a');
      expect(e.syncPath, 'sync/ep01.json');
      expect(e.paragraphCount, 23);
    });

    test('audioFileName هو اسم الملف فقط — وعليه يُبنى رابط الإصدار', () {
      expect(Episode.fromJson(json).audioFileName, 'ep01.m4a');
    });

    test('paragraphCount الناقص يصير صفراً', () {
      final e = Episode.fromJson({...json}..remove('paragraphCount'));
      expect(e.paragraphCount, 0);
    });

    test('durationObject بالملّي ثانية', () {
      expect(
        Episode.fromJson(json).durationObject,
        const Duration(milliseconds: 822300),
      );
    });
  });

  group('EpisodeIndex', () {
    test('fromJson يقرأ السلسلة والمصدر وقائمة الحلقات', () {
      final index = EpisodeIndex.fromJson({
        'series': 'القواعد الفقهية',
        'source': 'إذاعة القرآن الكريم - دولة الكويت',
        'episodes': [
          {
            'id': 'ep01',
            'number': 1,
            'title': 'الحلقة 1',
            'duration': 10.0,
            'audio': 'audio/ep01.m4a',
            'text': 'text/ep01.txt',
            'sync': 'sync/ep01.json',
          },
        ],
      });
      expect(index.series, 'القواعد الفقهية');
      expect(index.episodes, hasLength(1));
      expect(index.episodes.first.id, 'ep01');
    });
  });
}
