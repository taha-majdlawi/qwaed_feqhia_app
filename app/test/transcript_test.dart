import 'package:flutter_test/flutter_test.dart';
import 'package:qawaid_fiqhiyya/models/episode.dart';

EpisodeTranscript buildTranscript(List<(double, double)> spans) =>
    EpisodeTranscript(
      id: 'ep01',
      paragraphs: [
        for (var i = 0; i < spans.length; i++)
          Paragraph(
            index: i + 1,
            start: spans[i].$1,
            end: spans[i].$2,
            text: 'فقرة ${i + 1}',
          ),
      ],
    );

void main() {
  group('EpisodeTranscript.indexAt', () {
    final transcript = buildTranscript([
      (0.0, 18.0),
      (18.0, 34.6),
      (34.6, 47.0),
      (47.0, 90.0),
    ]);

    test('يجد الفقرة التي يقع فيها الوقت', () {
      expect(transcript.indexAt(0), 0);
      expect(transcript.indexAt(10), 0);
      expect(transcript.indexAt(18), 1);
      expect(transcript.indexAt(34.5), 1);
      expect(transcript.indexAt(34.6), 2);
      expect(transcript.indexAt(89.9), 3);
    });

    test('بداية الفقرة تنتمي إليها ونهايتها للتالية', () {
      expect(transcript.indexAt(47.0), 3);
      expect(transcript.indexAt(46.999), 2);
    });

    test('ما بعد آخر فقرة يعطي آخر فقرة', () {
      expect(transcript.indexAt(90.0), 3);
      expect(transcript.indexAt(10000), 3);
    });

    test('وقت سالب يعطي أول فقرة', () {
      expect(transcript.indexAt(-5), 0);
    });

    test('نص بلا فقرات يعطي -1', () {
      expect(buildTranscript([]).indexAt(5), -1);
    });

    test('فجوة بين فقرتين تُنسب للفقرة السابقة', () {
      final gapped = buildTranscript([(0.0, 10.0), (20.0, 30.0)]);
      expect(gapped.indexAt(15), 0);
    });

    test('البحث الثنائي صحيح على عدد كبير من الفقرات', () {
      final many = buildTranscript([
        for (var i = 0; i < 500; i++) (i * 10.0, (i + 1) * 10.0),
      ]);
      for (final probe in [0, 7, 99, 2500, 4999]) {
        expect(many.indexAt(probe.toDouble()), probe ~/ 10);
      }
    });
  });

  group('Paragraph', () {
    test('contains يشمل البداية دون النهاية', () {
      final p = Paragraph(index: 1, start: 5, end: 10, text: 'نص');
      expect(p.contains(5), isTrue);
      expect(p.contains(9.99), isTrue);
      expect(p.contains(10), isFalse);
      expect(p.contains(4.99), isFalse);
    });

    test('يحوّل الثواني إلى Duration', () {
      final p = Paragraph(index: 1, start: 34.6, end: 47, text: 'نص');
      expect(p.startObject, const Duration(milliseconds: 34600));
      expect(p.endObject, const Duration(seconds: 47));
    });

    test('يخزّن نسخة مطبّعة للبحث', () {
      final p = Paragraph(index: 1, start: 0, end: 1, text: 'الضَّرَرُ يُزَالُ');
      expect(p.normalized, 'الضرر يزال');
    });
  });

  group('Episode', () {
    test('يقرأ JSON ويشتق اسم ملف الصوت', () {
      final episode = Episode.fromJson(const {
        'id': 'ep07',
        'number': 7,
        'title': 'القواعد الفقهية – الحلقة 7',
        'duration': 822.3,
        'audio': 'audio/ep07.m4a',
        'text': 'text/ep07.txt',
        'sync': 'sync/ep07.json',
        'paragraphCount': 23,
      });

      expect(episode.id, 'ep07');
      expect(episode.number, 7);
      expect(episode.audioFileName, 'ep07.m4a');
      expect(episode.durationObject, const Duration(milliseconds: 822300));
    });

    test('paragraphCount اختياري', () {
      final episode = Episode.fromJson(const {
        'id': 'ep01',
        'number': 1,
        'title': 'حلقة',
        'duration': 10,
        'audio': 'audio/ep01.m4a',
        'text': 'text/ep01.txt',
        'sync': 'sync/ep01.json',
      });
      expect(episode.paragraphCount, 0);
    });
  });
}
