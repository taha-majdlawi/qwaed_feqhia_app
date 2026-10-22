import '../core/arabic.dart';

/// حلقة من السلسلة، كما في episodes.json.
class Episode {
  const Episode({
    required this.id,
    required this.number,
    required this.title,
    required this.duration,
    required this.audioPath,
    required this.textPath,
    required this.syncPath,
    required this.paragraphCount,
  });

  final String id;
  final int number;
  final String title;
  final double duration;
  final String audioPath;
  final String textPath;
  final String syncPath;
  final int paragraphCount;

  Duration get durationObject =>
      Duration(milliseconds: (duration * 1000).round());

  /// اسم ملف الصوت فقط، مثل «ep01.m4a».
  String get audioFileName => audioPath.split('/').last;

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
        id: json['id'] as String,
        number: (json['number'] as num).toInt(),
        title: json['title'] as String,
        duration: (json['duration'] as num).toDouble(),
        audioPath: json['audio'] as String,
        textPath: json['text'] as String,
        syncPath: json['sync'] as String,
        paragraphCount: (json['paragraphCount'] as num?)?.toInt() ?? 0,
      );
}

/// فهرس السلسلة كاملاً.
class EpisodeIndex {
  const EpisodeIndex({
    required this.series,
    required this.source,
    required this.episodes,
  });

  final String series;
  final String source;
  final List<Episode> episodes;

  factory EpisodeIndex.fromJson(Map<String, dynamic> json) => EpisodeIndex(
        series: json['series'] as String? ?? '',
        source: json['source'] as String? ?? '',
        episodes: (json['episodes'] as List<dynamic>)
            .map((e) => Episode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// فقرة نصية موقوتة داخل حلقة.
class Paragraph {
  Paragraph({
    required this.index,
    required this.start,
    required this.end,
    required this.text,
  }) : norm = NormalizedText.of(text);

  final int index;
  final double start;
  final double end;
  final String text;

  /// نسخة مطبّعة من النص مع خريطة المواضع، تُستخدم في البحث والتظليل.
  final NormalizedText norm;

  String get normalized => norm.value;

  Duration get startObject => Duration(milliseconds: (start * 1000).round());
  Duration get endObject => Duration(milliseconds: (end * 1000).round());

  bool contains(double seconds) => seconds >= start && seconds < end;

  factory Paragraph.fromJson(Map<String, dynamic> json) => Paragraph(
        index: (json['index'] as num).toInt(),
        start: (json['start'] as num).toDouble(),
        end: (json['end'] as num).toDouble(),
        text: (json['text'] as String).trim(),
      );
}

/// النص الموقوت لحلقة واحدة (sync/epXX.json).
class EpisodeTranscript {
  const EpisodeTranscript({required this.id, required this.paragraphs});

  final String id;
  final List<Paragraph> paragraphs;

  /// رقم الفقرة التي يقع فيها الوقت المعطى، أو -1 إن لم توجد.
  int indexAt(double seconds) {
    if (paragraphs.isEmpty) return -1;
    var low = 0;
    var high = paragraphs.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final p = paragraphs[mid];
      if (seconds < p.start) {
        high = mid - 1;
      } else if (seconds >= p.end) {
        low = mid + 1;
      } else {
        return mid;
      }
    }
    // بين فقرتين أو بعد آخر فقرة: أعد أقرب فقرة سابقة.
    return (low - 1).clamp(0, paragraphs.length - 1);
  }

  factory EpisodeTranscript.fromJson(Map<String, dynamic> json) =>
      EpisodeTranscript(
        id: json['id'] as String? ?? '',
        paragraphs: (json['paragraphs'] as List<dynamic>)
            .map((e) => Paragraph.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
