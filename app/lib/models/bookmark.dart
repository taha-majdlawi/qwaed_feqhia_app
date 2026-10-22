/// علامة يضعها المستخدم عند لحظة معيّنة من حلقة.
class Bookmark {
  const Bookmark({
    required this.id,
    required this.episodeId,
    required this.position,
    required this.note,
    required this.createdAt,
    this.paragraphIndex,
  });

  final String id;
  final String episodeId;

  /// موضع العلامة بالثواني.
  final double position;
  final String note;
  final DateTime createdAt;
  final int? paragraphIndex;

  Duration get positionObject =>
      Duration(milliseconds: (position * 1000).round());

  Bookmark copyWith({String? note}) => Bookmark(
        id: id,
        episodeId: episodeId,
        position: position,
        note: note ?? this.note,
        createdAt: createdAt,
        paragraphIndex: paragraphIndex,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'episodeId': episodeId,
        'position': position,
        'note': note,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'paragraphIndex': paragraphIndex,
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        id: json['id'] as String,
        episodeId: json['episodeId'] as String,
        position: (json['position'] as num).toDouble(),
        note: json['note'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (json['createdAt'] as num).toInt()),
        paragraphIndex: (json['paragraphIndex'] as num?)?.toInt(),
      );
}

/// تقدّم الاستماع في حلقة.
class PlaybackProgress {
  const PlaybackProgress({
    required this.episodeId,
    required this.position,
    required this.duration,
    required this.updatedAt,
    this.completed = false,
  });

  final String episodeId;
  final double position;
  final double duration;
  final DateTime updatedAt;
  final bool completed;

  Duration get positionObject =>
      Duration(milliseconds: (position * 1000).round());

  double get fraction =>
      duration <= 0 ? 0 : (position / duration).clamp(0.0, 1.0);

  bool get started => position > 5;

  Map<String, dynamic> toJson() => {
        'episodeId': episodeId,
        'position': position,
        'duration': duration,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'completed': completed,
      };

  factory PlaybackProgress.fromJson(Map<String, dynamic> json) =>
      PlaybackProgress(
        episodeId: json['episodeId'] as String,
        position: (json['position'] as num).toDouble(),
        duration: (json['duration'] as num?)?.toDouble() ?? 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (json['updatedAt'] as num).toInt()),
        completed: json['completed'] as bool? ?? false,
      );
}

/// نتيجة بحث داخل نصوص الحلقات.
class SearchHit {
  const SearchHit({
    required this.episodeId,
    required this.episodeNumber,
    required this.episodeTitle,
    required this.paragraphIndex,
    required this.start,
    required this.text,
    required this.matchStart,
    required this.matchEnd,
  });

  final String episodeId;
  final int episodeNumber;
  final String episodeTitle;
  final int paragraphIndex;
  final double start;
  final String text;

  /// موضع المطابقة داخل `text` الأصلي.
  final int matchStart;
  final int matchEnd;
}
