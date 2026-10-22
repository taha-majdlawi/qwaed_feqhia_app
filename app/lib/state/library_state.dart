import 'package:flutter/foundation.dart';

import '../models/bookmark.dart';
import '../models/episode.dart';
import '../services/data_repository.dart';
import '../services/download_service.dart';
import '../services/storage_service.dart';

enum EpisodeSort { byNumber, byNumberDesc, byDuration, recentlyPlayed }

enum EpisodeFilter { all, inProgress, completed, notStarted, downloaded }

/// حالة المكتبة: الحلقات والمفضلة والعلامات والتقدّم.
class LibraryState extends ChangeNotifier {
  LibraryState();

  final DataRepository _repo = DataRepository.instance;

  bool _ready = false;
  String? _loadError;
  Set<String> _favorites = {};
  List<Bookmark> _bookmarks = [];
  Map<String, PlaybackProgress> _progress = {};
  EpisodeSort _sort = EpisodeSort.byNumber;
  EpisodeFilter _filter = EpisodeFilter.all;
  String _query = '';

  bool get isReady => _ready;
  String? get loadError => _loadError;
  List<Episode> get allEpisodes => _repo.episodes;
  Set<String> get favorites => _favorites;
  List<Bookmark> get bookmarks => _bookmarks;
  EpisodeSort get sort => _sort;
  EpisodeFilter get filter => _filter;
  String get query => _query;

  Future<void> load() async {
    try {
      await _repo.loadIndex();
      final storage = StorageService.instance;
      _favorites = storage.favorites;
      _bookmarks = storage.bookmarks
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _progress = storage.allProgress();
      await DownloadService.instance.refresh(_repo.episodes);
      _ready = true;
      _loadError = null;
    } catch (e) {
      _loadError = 'تعذّر تحميل بيانات الحلقات: $e';
      _ready = true;
    }
    notifyListeners();
  }

  // ===== التقدّم =====
  PlaybackProgress? progressOf(String episodeId) => _progress[episodeId];

  bool isCompleted(String episodeId) => _progress[episodeId]?.completed ?? false;

  double fractionOf(String episodeId) => _progress[episodeId]?.fraction ?? 0;

  /// يعيد قراءة التقدّم من التخزين (بعد انتهاء التشغيل مثلاً).
  void refreshProgress() {
    _progress = StorageService.instance.allProgress();
    notifyListeners();
  }

  Future<void> markCompleted(Episode episode, bool completed) async {
    final updated = PlaybackProgress(
      episodeId: episode.id,
      position: 0,
      duration: episode.duration,
      updatedAt: DateTime.now(),
      completed: completed,
    );
    await StorageService.instance.saveProgress(updated);
    _progress[episode.id] = updated;
    notifyListeners();
  }

  Future<void> resetProgress(Episode episode) async {
    await StorageService.instance.clearProgress(episode.id);
    _progress.remove(episode.id);
    notifyListeners();
  }

  /// الحلقة التي يُستحسن متابعتها: آخر حلقة لم تكتمل.
  Episode? get continueListening {
    PlaybackProgress? best;
    for (final p in _progress.values) {
      if (p.completed || !p.started) continue;
      if (best == null || p.updatedAt.isAfter(best.updatedAt)) best = p;
    }
    if (best == null) return null;
    return _repo.episodeById(best.episodeId);
  }

  int get completedCount =>
      _progress.values.where((p) => p.completed).length;

  int get inProgressCount =>
      _progress.values.where((p) => !p.completed && p.started).length;

  /// مجموع ما استُمع إليه تقريباً.
  Duration get listenedTotal {
    var seconds = 0.0;
    for (final p in _progress.values) {
      seconds += p.completed ? p.duration : p.position;
    }
    return Duration(seconds: seconds.round());
  }

  // ===== المفضلة =====
  bool isFavorite(String episodeId) => _favorites.contains(episodeId);

  Future<void> toggleFavorite(String episodeId) async {
    if (!_favorites.remove(episodeId)) _favorites.add(episodeId);
    await StorageService.instance.setFavorites(_favorites);
    notifyListeners();
  }

  List<Episode> get favoriteEpisodes =>
      allEpisodes.where((e) => _favorites.contains(e.id)).toList();

  // ===== العلامات =====
  List<Bookmark> bookmarksOf(String episodeId) =>
      _bookmarks.where((b) => b.episodeId == episodeId).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

  Future<Bookmark> addBookmark({
    required String episodeId,
    required double position,
    required String note,
    int? paragraphIndex,
  }) async {
    final bookmark = Bookmark(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      episodeId: episodeId,
      position: position,
      note: note,
      createdAt: DateTime.now(),
      paragraphIndex: paragraphIndex,
    );
    _bookmarks = [bookmark, ..._bookmarks];
    await StorageService.instance.setBookmarks(_bookmarks);
    notifyListeners();
    return bookmark;
  }

  Future<void> removeBookmark(String id) async {
    _bookmarks = _bookmarks.where((b) => b.id != id).toList();
    await StorageService.instance.setBookmarks(_bookmarks);
    notifyListeners();
  }

  Future<void> updateBookmarkNote(String id, String note) async {
    _bookmarks = _bookmarks
        .map((b) => b.id == id ? b.copyWith(note: note) : b)
        .toList();
    await StorageService.instance.setBookmarks(_bookmarks);
    notifyListeners();
  }

  // ===== الفرز والتصفية =====
  void setSort(EpisodeSort value) {
    _sort = value;
    notifyListeners();
  }

  void setFilter(EpisodeFilter value) {
    _filter = value;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  /// قائمة الحلقات بعد تطبيق التصفية والفرز والبحث بالعنوان/الرقم.
  List<Episode> get visibleEpisodes {
    final downloads = DownloadService.instance;
    var list = allEpisodes.where((e) {
      switch (_filter) {
        case EpisodeFilter.all:
          break;
        case EpisodeFilter.inProgress:
          final p = _progress[e.id];
          if (p == null || p.completed || !p.started) return false;
        case EpisodeFilter.completed:
          if (!(_progress[e.id]?.completed ?? false)) return false;
        case EpisodeFilter.notStarted:
          final p = _progress[e.id];
          if (p != null && (p.started || p.completed)) return false;
        case EpisodeFilter.downloaded:
          if (!downloads.isDownloaded(e.id)) return false;
      }
      if (_query.trim().isEmpty) return true;
      final q = _query.trim();
      return e.title.contains(q) || '${e.number}'.contains(q);
    }).toList();

    switch (_sort) {
      case EpisodeSort.byNumber:
        list.sort((a, b) => a.number.compareTo(b.number));
      case EpisodeSort.byNumberDesc:
        list.sort((a, b) => b.number.compareTo(a.number));
      case EpisodeSort.byDuration:
        list.sort((a, b) => b.duration.compareTo(a.duration));
      case EpisodeSort.recentlyPlayed:
        list.sort((a, b) {
          final pa = _progress[a.id]?.updatedAt;
          final pb = _progress[b.id]?.updatedAt;
          if (pa == null && pb == null) return a.number.compareTo(b.number);
          if (pa == null) return 1;
          if (pb == null) return -1;
          return pb.compareTo(pa);
        });
    }
    return list;
  }
}
