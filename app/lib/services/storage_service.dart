import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bookmark.dart';

/// تخزين محلي لكل ما يخصّ المستخدم: التقدّم، المفضلة، العلامات، الإعدادات.
class StorageService {
  StorageService._(this._prefs);

  static StorageService? _instance;
  static StorageService get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('StorageService.init() لم تُستدعَ بعد');
    }
    return i;
  }

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return _instance = StorageService._(prefs);
  }

  final SharedPreferences _prefs;

  // ===== مفاتيح =====
  static const _kFavorites = 'favorites';
  static const _kBookmarks = 'bookmarks';
  static const _kProgressPrefix = 'progress.';
  static const _kLastEpisode = 'last_episode';
  static const _kThemeMode = 'theme_mode';
  static const _kFontScale = 'font_scale';
  static const _kSpeed = 'playback_speed';
  static const _kAutoScroll = 'auto_scroll';
  static const _kKeepAwake = 'keep_awake';
  static const _kArabicDigits = 'arabic_digits';
  static const _kSearchHistory = 'search_history';
  static const _kSeenIntro = 'seen_intro';

  // ===== المفضلة =====
  Set<String> get favorites =>
      (_prefs.getStringList(_kFavorites) ?? const []).toSet();

  Future<void> setFavorites(Set<String> ids) =>
      _prefs.setStringList(_kFavorites, ids.toList());

  // ===== التقدّم =====
  PlaybackProgress? progressFor(String episodeId) {
    final raw = _prefs.getString('$_kProgressPrefix$episodeId');
    if (raw == null) return null;
    try {
      return PlaybackProgress.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProgress(PlaybackProgress progress) => _prefs.setString(
        '$_kProgressPrefix${progress.episodeId}',
        jsonEncode(progress.toJson()),
      );

  Future<void> clearProgress(String episodeId) =>
      _prefs.remove('$_kProgressPrefix$episodeId');

  Map<String, PlaybackProgress> allProgress() {
    final result = <String, PlaybackProgress>{};
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(_kProgressPrefix)) continue;
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        final p =
            PlaybackProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        result[p.episodeId] = p;
      } catch (_) {
        // تجاهل أي سجل تالف
      }
    }
    return result;
  }

  // ===== العلامات =====
  List<Bookmark> get bookmarks {
    final raw = _prefs.getString(_kBookmarks);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setBookmarks(List<Bookmark> items) => _prefs.setString(
        _kBookmarks,
        jsonEncode(items.map((b) => b.toJson()).toList()),
      );

  // ===== آخر حلقة =====
  String? get lastEpisodeId => _prefs.getString(_kLastEpisode);
  Future<void> setLastEpisodeId(String id) =>
      _prefs.setString(_kLastEpisode, id);

  // ===== سجل البحث =====
  List<String> get searchHistory =>
      _prefs.getStringList(_kSearchHistory) ?? const [];

  Future<void> setSearchHistory(List<String> items) =>
      _prefs.setStringList(_kSearchHistory, items);

  // ===== شاشة الترحيب =====
  bool get seenIntro => _prefs.getBool(_kSeenIntro) ?? false;
  Future<void> setSeenIntro() => _prefs.setBool(_kSeenIntro, true);

  // ===== الإعدادات =====
  int get themeModeIndex => _prefs.getInt(_kThemeMode) ?? 0;
  Future<void> setThemeModeIndex(int value) =>
      _prefs.setInt(_kThemeMode, value);

  double get fontScale => _prefs.getDouble(_kFontScale) ?? 1.0;
  Future<void> setFontScale(double value) =>
      _prefs.setDouble(_kFontScale, value);

  double get playbackSpeed => _prefs.getDouble(_kSpeed) ?? 1.0;
  Future<void> setPlaybackSpeed(double value) =>
      _prefs.setDouble(_kSpeed, value);

  bool get autoScroll => _prefs.getBool(_kAutoScroll) ?? true;
  Future<void> setAutoScroll(bool value) => _prefs.setBool(_kAutoScroll, value);

  bool get keepAwake => _prefs.getBool(_kKeepAwake) ?? false;
  Future<void> setKeepAwake(bool value) => _prefs.setBool(_kKeepAwake, value);

  bool get arabicDigits => _prefs.getBool(_kArabicDigits) ?? true;
  Future<void> setArabicDigits(bool value) =>
      _prefs.setBool(_kArabicDigits, value);

  Future<void> clearAll() => _prefs.clear();
}
