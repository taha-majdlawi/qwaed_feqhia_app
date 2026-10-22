import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../core/constants.dart';
import '../models/bookmark.dart';
import '../models/episode.dart';
import 'data_repository.dart';
import 'download_service.dart';
import 'storage_service.dart';

enum PlaybackRepeatMode { off, episode, paragraph }

/// محرّك التشغيل: يربط الصوت بالنص الموقوت، ويحفظ التقدّم تلقائياً.
class PlayerController extends ChangeNotifier {
  PlayerController._() {
    _attachListeners();
  }

  static final PlayerController instance = PlayerController._();

  final AudioPlayer _player = AudioPlayer();
  final DataRepository _repo = DataRepository.instance;

  AudioPlayer get player => _player;

  Episode? _episode;
  EpisodeTranscript? _transcript;
  bool _loading = false;
  String? _error;
  PlaybackRepeatMode _repeat = PlaybackRepeatMode.off;
  Timer? _sleepTimer;
  Duration? _sleepRemaining;
  bool _stopAtEndOfEpisode = false;

  /// رقم الفقرة الجارية؛ منفصل عن notifyListeners كي لا تُعاد بناء الشاشة كلها.
  final ValueNotifier<int> currentParagraph = ValueNotifier<int>(-1);

  Episode? get episode => _episode;
  EpisodeTranscript? get transcript => _transcript;
  bool get isLoading => _loading;
  String? get error => _error;
  PlaybackRepeatMode get repeatMode => _repeat;
  Duration? get sleepRemaining => _sleepRemaining;
  bool get stopAtEndOfEpisode => _stopAtEndOfEpisode;
  bool get hasEpisode => _episode != null;
  bool get isPlaying => _player.playing;
  double get speed => _player.speed;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Duration get position => _player.position;
  Duration get duration =>
      _player.duration ?? _episode?.durationObject ?? Duration.zero;

  Timer? _saveTimer;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;

  Future<void> initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } catch (_) {
      // غير مدعوم على بعض المنصّات
    }
    await _player.setSpeed(StorageService.instance.playbackSpeed);
  }

  void _attachListeners() {
    _positionSub = _player.positionStream.listen((pos) {
      _updateParagraph(pos);
      _maybeRepeatParagraph(pos);
    });

    _stateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _onCompleted();
      }
      notifyListeners();
    });

    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_player.playing) _persistProgress();
    });
  }

  void _updateParagraph(Duration pos) {
    final t = _transcript;
    if (t == null) return;
    final index = t.indexAt(pos.inMilliseconds / 1000);
    if (index != currentParagraph.value) {
      currentParagraph.value = index;
    }
  }

  void _maybeRepeatParagraph(Duration pos) {
    if (_repeat != PlaybackRepeatMode.paragraph) return;
    final t = _transcript;
    final index = currentParagraph.value;
    if (t == null || index < 0 || index >= t.paragraphs.length) return;
    final p = t.paragraphs[index];
    if (pos.inMilliseconds / 1000 >= p.end - 0.05) {
      _player.seek(p.startObject);
    }
  }

  Future<void> _onCompleted() async {
    final episode = _episode;
    if (episode != null) {
      await StorageService.instance.saveProgress(PlaybackProgress(
        episodeId: episode.id,
        position: 0,
        duration: episode.duration,
        updatedAt: DateTime.now(),
        completed: true,
      ));
    }

    if (_stopAtEndOfEpisode) {
      _stopAtEndOfEpisode = false;
      await _player.pause();
      await _player.seek(Duration.zero);
      notifyListeners();
      return;
    }

    switch (_repeat) {
      case PlaybackRepeatMode.episode:
      case PlaybackRepeatMode.paragraph:
        await _player.seek(Duration.zero);
        await _player.play();
      case PlaybackRepeatMode.off:
        await playNext();
    }
  }

  /// يفتح حلقة ويبدأ التشغيل من آخر موضع محفوظ (أو من [startAt] إن مُرّر).
  Future<void> open(
    Episode episode, {
    Duration? startAt,
    bool autoPlay = true,
  }) async {
    if (_episode?.id == episode.id && _player.audioSource != null) {
      if (startAt != null) await seek(startAt);
      if (autoPlay && !_player.playing) await _player.play();
      return;
    }

    await _persistProgress();

    _loading = true;
    _error = null;
    _episode = episode;
    _transcript = null;
    currentParagraph.value = -1;
    notifyListeners();

    try {
      _transcript = await _repo.loadTranscript(episode.id);
      final uri = await DownloadService.instance.sourceFor(episode);

      await _player.setAudioSource(
        AudioSource.uri(
          uri,
          tag: MediaItem(
            id: episode.id,
            title: episode.title,
            album: AppConstants.appName,
            artist: AppConstants.author,
            duration: episode.durationObject,
          ),
        ),
        initialPosition: startAt ?? _savedPositionFor(episode),
      );
      await _player.setSpeed(StorageService.instance.playbackSpeed);
      await StorageService.instance.setLastEpisodeId(episode.id);

      _loading = false;
      notifyListeners();

      if (autoPlay) await _player.play();
    } catch (e) {
      _loading = false;
      _error = _describeError(e);
      notifyListeners();
    }
  }

  String _describeError(Object e) {
    final text = e.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection')) {
      return 'تعذّر الوصول إلى ملف الصوت. تأكّد من الاتصال بالإنترنت، أو حمّل الحلقة أولاً.';
    }
    if (text.contains('404')) {
      return 'ملف الصوت غير متاح على الخادم بعد.';
    }
    return 'تعذّر تشغيل الحلقة.';
  }

  Duration _savedPositionFor(Episode episode) {
    final saved = StorageService.instance.progressFor(episode.id);
    if (saved == null || saved.completed) return Duration.zero;
    final pos = saved.positionObject;
    // لا تستأنف من آخر عشر ثوانٍ
    if (pos >= episode.durationObject - const Duration(seconds: 10)) {
      return Duration.zero;
    }
    return pos;
  }

  Future<void> retry() async {
    final episode = _episode;
    if (episode == null) return;
    final at = _player.position;
    _episode = null;
    await open(episode, startAt: at);
  }

  Future<void> playPause() async {
    if (_player.playing) {
      await _player.pause();
      await _persistProgress();
    } else {
      await _player.play();
    }
  }

  Future<void> seek(Duration to) async {
    final total = duration;
    var clamped = to < Duration.zero ? Duration.zero : to;
    if (total > Duration.zero && clamped > total) clamped = total;
    await _player.seek(clamped);
    _updateParagraph(clamped);
  }

  Future<void> skip(Duration delta) => seek(_player.position + delta);

  Future<void> seekToParagraph(int index) async {
    final t = _transcript;
    if (t == null || index < 0 || index >= t.paragraphs.length) return;
    await seek(t.paragraphs[index].startObject);
    if (!_player.playing) await _player.play();
  }

  Future<void> nextParagraph() => seekToParagraph(currentParagraph.value + 1);

  Future<void> previousParagraph() async {
    final t = _transcript;
    final index = currentParagraph.value;
    if (t == null || index < 0) return;
    // إن مضى أكثر من ثانيتين على بداية الفقرة، أعد الفقرة نفسها.
    final p = t.paragraphs[index];
    final elapsed = _player.position.inMilliseconds / 1000 - p.start;
    await seekToParagraph(elapsed > 2 ? index : index - 1);
  }

  Future<void> setSpeed(double value) async {
    await _player.setSpeed(value);
    await StorageService.instance.setPlaybackSpeed(value);
    notifyListeners();
  }

  void cycleRepeatMode() {
    _repeat = switch (_repeat) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.episode,
      PlaybackRepeatMode.episode => PlaybackRepeatMode.paragraph,
      PlaybackRepeatMode.paragraph => PlaybackRepeatMode.off,
    };
    notifyListeners();
  }

  Future<void> playNext() async {
    final current = _episode;
    if (current == null) return;
    final next = _repo.episodeByNumber(current.number + 1);
    if (next == null) {
      await _player.pause();
      await _player.seek(Duration.zero);
      notifyListeners();
      return;
    }
    await open(next, startAt: Duration.zero);
  }

  Future<void> playPrevious() async {
    final current = _episode;
    if (current == null) return;
    // إن مضى أكثر من خمس ثوانٍ، ارجع لبداية الحلقة نفسها.
    if (_player.position > const Duration(seconds: 5)) {
      await seek(Duration.zero);
      return;
    }
    final previous = _repo.episodeByNumber(current.number - 1);
    if (previous == null) return;
    await open(previous, startAt: Duration.zero);
  }

  bool get hasNext {
    final current = _episode;
    return current != null && _repo.episodeByNumber(current.number + 1) != null;
  }

  bool get hasPrevious {
    final current = _episode;
    return current != null && _repo.episodeByNumber(current.number - 1) != null;
  }

  // ===== مؤقّت النوم =====
  void startSleepTimer(Duration duration) {
    cancelSleepTimer();
    _sleepRemaining = duration;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining =
          (_sleepRemaining ?? Duration.zero) - const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        timer.cancel();
        _sleepTimer = null;
        _sleepRemaining = null;
        await _player.pause();
        await _persistProgress();
      } else {
        _sleepRemaining = remaining;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void sleepAtEndOfEpisode() {
    cancelSleepTimer();
    _stopAtEndOfEpisode = true;
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepRemaining = null;
    _stopAtEndOfEpisode = false;
    notifyListeners();
  }

  bool get hasSleepTimer => _sleepRemaining != null || _stopAtEndOfEpisode;

  // ===== حفظ التقدّم =====
  Future<void> _persistProgress() async {
    final episode = _episode;
    if (episode == null) return;
    final pos = _player.position;
    if (pos <= Duration.zero) return;
    final total = duration;
    final completed =
        total > Duration.zero && pos >= total - const Duration(seconds: 15);
    await StorageService.instance.saveProgress(PlaybackProgress(
      episodeId: episode.id,
      position: completed ? 0 : pos.inMilliseconds / 1000,
      duration: total.inMilliseconds / 1000,
      updatedAt: DateTime.now(),
      completed: completed,
    ));
  }

  Future<void> saveNow() => _persistProgress();

  /// يُستدعى بعد تحميل الحلقة محلياً كي ينتقل التشغيل إلى الملف المحلي.
  Future<void> switchToLocalIfPossible(Episode episode) async {
    if (_episode?.id != episode.id) return;
    final path = await DownloadService.instance.localPath(episode);
    if (!await File(path).exists()) return;
    final at = _player.position;
    final wasPlaying = _player.playing;
    _episode = null;
    await open(episode, startAt: at, autoPlay: wasPlaying);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    currentParagraph.dispose();
    _player.dispose();
    super.dispose();
  }
}
