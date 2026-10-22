import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/arabic.dart';
import '../core/constants.dart';
import '../models/bookmark.dart';
import '../models/episode.dart';

/// مصدر بيانات الحلقات: الفهرس والنصوص الموقوتة والبحث فيها.
///
/// كل شيء محمّل من assets داخل التطبيق، فلا يحتاج اتصالاً بالإنترنت.
class DataRepository {
  DataRepository._();

  static final DataRepository instance = DataRepository._();

  EpisodeIndex? _index;
  final Map<String, EpisodeTranscript> _transcripts = {};
  bool _allTranscriptsLoaded = false;

  List<Episode> get episodes => _index?.episodes ?? const [];

  Episode? episodeById(String id) {
    for (final e in episodes) {
      if (e.id == id) return e;
    }
    return null;
  }

  Episode? episodeByNumber(int number) {
    for (final e in episodes) {
      if (e.number == number) return e;
    }
    return null;
  }

  /// يحمّل فهرس الحلقات مرة واحدة.
  Future<EpisodeIndex> loadIndex() async {
    final cached = _index;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(AppConstants.episodesAsset);
    final parsed = EpisodeIndex.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _index = parsed;
    return parsed;
  }

  /// يحمّل النص الموقوت لحلقة واحدة (مع تخزين مؤقت).
  Future<EpisodeTranscript> loadTranscript(String episodeId) async {
    final cached = _transcripts[episodeId];
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(AppConstants.syncAsset(episodeId));
    final parsed = EpisodeTranscript.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _transcripts[episodeId] = parsed;
    return parsed;
  }

  /// يحمّل نصوص كل الحلقات؛ لازم للبحث الشامل.
  Future<void> loadAllTranscripts({void Function(int done, int total)? onProgress}) async {
    if (_allTranscriptsLoaded) return;
    await loadIndex();
    final all = episodes;
    for (var i = 0; i < all.length; i++) {
      await loadTranscript(all[i].id);
      onProgress?.call(i + 1, all.length);
    }
    _allTranscriptsLoaded = true;
  }

  bool get isSearchReady => _allTranscriptsLoaded;

  /// بحث نصي شامل في كل الحلقات، يتجاهل التشكيل واختلاف الهمزات.
  ///
  /// [episodeFilter] يحصر البحث في حلقة واحدة إن مُرّر.
  List<SearchHit> search(
    String query, {
    String? episodeFilter,
    int limit = 300,
  }) {
    final needle = normalizeArabic(query);
    if (needle.isEmpty) return const [];

    final hits = <SearchHit>[];
    for (final episode in episodes) {
      if (episodeFilter != null && episode.id != episodeFilter) continue;
      final transcript = _transcripts[episode.id];
      if (transcript == null) continue;

      for (final paragraph in transcript.paragraphs) {
        var from = 0;
        while (true) {
          final at = paragraph.normalized.indexOf(needle, from);
          if (at < 0) break;
          final (start, end) =
              paragraph.norm.toOriginalRange(at, needle.length);
          hits.add(SearchHit(
            episodeId: episode.id,
            episodeNumber: episode.number,
            episodeTitle: episode.title,
            paragraphIndex: paragraph.index,
            start: paragraph.start,
            text: paragraph.text,
            matchStart: start,
            matchEnd: end,
          ));
          if (hits.length >= limit) return hits;
          from = at + needle.length;
        }
      }
    }
    return hits;
  }

  /// عدد مرات ورود كلمة في كل السلسلة (للإحصاءات).
  int countOccurrences(String query) {
    final needle = normalizeArabic(query);
    if (needle.isEmpty) return 0;
    var total = 0;
    for (final transcript in _transcripts.values) {
      for (final paragraph in transcript.paragraphs) {
        var from = 0;
        while (true) {
          final at = paragraph.normalized.indexOf(needle, from);
          if (at < 0) break;
          total++;
          from = at + needle.length;
        }
      }
    }
    return total;
  }

  /// النص الكامل لحلقة (للمشاركة أو النسخ).
  Future<String> loadPlainText(String episodeId) =>
      rootBundle.loadString(AppConstants.textAsset(episodeId));
}
