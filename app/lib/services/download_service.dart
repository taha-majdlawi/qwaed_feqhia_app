import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../models/episode.dart';

enum DownloadStatus { none, running, done, failed }

class DownloadInfo {
  const DownloadInfo({
    required this.status,
    this.progress = 0,
    this.received = 0,
    this.total = 0,
    this.error,
  });

  final DownloadStatus status;
  final double progress;
  final int received;
  final int total;
  final String? error;
}

/// تحميل الحلقات للاستماع دون إنترنت، وإدارة الملفات المحفوظة.
class DownloadService extends ChangeNotifier {
  DownloadService._();

  static final DownloadService instance = DownloadService._();

  final Dio _dio = Dio();
  final Map<String, DownloadInfo> _state = {};
  final Map<String, CancelToken> _tokens = {};
  final Map<String, DateTime> _lastNotified = {};
  Directory? _dir;

  /// أقل فاصل بين تحديثين لشريط التقدّم. بدونه يُعاد بناء قائمة الحلقات
  /// مع كل قطعة بيانات، فيتأخّر قارئ المقبس حتى يُغلق الاتصال.
  static const Duration _progressInterval = Duration(milliseconds: 250);

  /// مجلد الصوتيات المحمّلة.
  Future<Directory> _audioDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}audio');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _dir = dir;
  }

  /// يفحص الملفات الموجودة على القرص عند بدء التطبيق.
  Future<void> refresh(List<Episode> episodes) async {
    final dir = await _audioDir();
    for (final episode in episodes) {
      final file = File('${dir.path}${Platform.pathSeparator}${episode.audioFileName}');
      if (await file.exists() && await file.length() > 0) {
        _state[episode.id] = const DownloadInfo(status: DownloadStatus.done);
      }
    }
    notifyListeners();
  }

  DownloadInfo infoFor(String episodeId) =>
      _state[episodeId] ?? const DownloadInfo(status: DownloadStatus.none);

  bool isDownloaded(String episodeId) =>
      infoFor(episodeId).status == DownloadStatus.done;

  bool get hasActiveDownloads =>
      _state.values.any((i) => i.status == DownloadStatus.running);

  int get downloadedCount =>
      _state.values.where((i) => i.status == DownloadStatus.done).length;

  Future<String> localPath(Episode episode) async {
    final dir = await _audioDir();
    return '${dir.path}${Platform.pathSeparator}${episode.audioFileName}';
  }

  /// مصدر التشغيل: الملف المحلي إن وُجد، وإلا الرابط البعيد.
  Future<Uri> sourceFor(Episode episode) async {
    final path = await localPath(episode);
    if (await File(path).exists()) return Uri.file(path);
    return Uri.parse('${AppConstants.audioBaseUrl}${episode.audioFileName}');
  }

  Uri remoteUri(Episode episode) =>
      Uri.parse('${AppConstants.audioBaseUrl}${episode.audioFileName}');

  /// عدد محاولات التحميل قبل الاستسلام. الملف ~٦ م.ب، والاتصال قد ينقطع،
  /// فنعيد المحاولة مستأنفين من حيث توقّفنا بدل البدء من الصفر.
  static const int _maxAttempts = 3;

  Future<void> download(Episode episode) async {
    if (infoFor(episode.id).status == DownloadStatus.running) return;
    if (isDownloaded(episode.id)) return;

    final target = await localPath(episode);
    final temp = '$target.part';
    final token = CancelToken();
    _tokens[episode.id] = token;
    _state[episode.id] = const DownloadInfo(status: DownloadStatus.running);
    notifyListeners();

    Object? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        await _fetchToFile(episode: episode, temp: temp, token: token);
        await File(temp).rename(target);
        _state[episode.id] = const DownloadInfo(status: DownloadStatus.done);
        lastError = null;
        break;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          await _safeDelete(temp);
          _state[episode.id] = const DownloadInfo(status: DownloadStatus.none);
          lastError = null;
          break;
        }
        lastError = e;
        debugPrint(
            'تعذّر تحميل ${episode.id} (محاولة $attempt): ${e.type} ${e.message}');
        if (e.response?.statusCode == 404) break;
      } catch (e) {
        lastError = e;
        debugPrint('تعذّر تحميل ${episode.id} (محاولة $attempt): $e');
      }

      if (attempt < _maxAttempts) {
        await Future<void>.delayed(Duration(seconds: attempt));
      }
    }

    if (lastError != null) {
      // نُبقي الجزء المحمّل كي تستأنف المحاولة القادمة من موضعه.
      _state[episode.id] = DownloadInfo(
        status: DownloadStatus.failed,
        error: lastError is DioException
            ? _messageFor(lastError)
            : 'فشل التحميل',
      );
    }

    _tokens.remove(episode.id);
    _lastNotified.remove(episode.id);
    notifyListeners();
  }

  /// ينزّل الملف إلى [temp]، مستأنفاً عبر ترويسة Range إن كان فيه جزء سابق.
  Future<void> _fetchToFile({
    required Episode episode,
    required String temp,
    required CancelToken token,
  }) async {
    final partFile = File(temp);
    final alreadyHave = await partFile.exists() ? await partFile.length() : 0;

    final response = await _dio.get<ResponseBody>(
      remoteUri(episode).toString(),
      cancelToken: token,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 3),
        headers: alreadyHave > 0 ? {'range': 'bytes=$alreadyHave-'} : null,
        validateStatus: (code) => code != null && code >= 200 && code < 300,
      ),
    );

    // 206 يعني أن الخادم قبل الاستئناف؛ غير ذلك نبدأ من جديد.
    final resuming = response.statusCode == 206 && alreadyHave > 0;
    final remaining = int.tryParse(
          response.headers.value(Headers.contentLengthHeader) ?? '',
        ) ??
        0;
    final total = resuming ? alreadyHave + remaining : remaining;

    final sink = partFile.openWrite(
      mode: resuming ? FileMode.append : FileMode.write,
    );
    var received = resuming ? alreadyHave : 0;

    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        _state[episode.id] = DownloadInfo(
          status: DownloadStatus.running,
          progress: total > 0 ? received / total : 0,
          received: received,
          total: total,
        );
        final now = DateTime.now();
        final last = _lastNotified[episode.id];
        if (last == null || now.difference(last) >= _progressInterval) {
          _lastNotified[episode.id] = now;
          notifyListeners();
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (total > 0 && received < total) {
      throw const SocketException('انقطع التحميل قبل اكتماله');
    }
  }

  void cancel(String episodeId) {
    _tokens[episodeId]?.cancel('أُلغي التحميل');
  }

  Future<void> delete(Episode episode) async {
    cancel(episode.id);
    final path = await localPath(episode);
    await _safeDelete(path);
    await _safeDelete('$path.part'); // أي جزء ناقص من محاولة سابقة
    _state.remove(episode.id);
    notifyListeners();
  }

  Future<void> deleteAll(List<Episode> episodes) async {
    for (final episode in episodes) {
      await delete(episode);
    }
  }

  /// مجموع حجم الملفات المحمّلة بالبايت.
  Future<int> usedBytes() async {
    final dir = await _audioDir();
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> _safeDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // لا شيء
    }
  }

  String _messageFor(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'انتهت مهلة الاتصال';
      case DioExceptionType.connectionError:
        return 'تعذّر الاتصال بالإنترنت';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 404) return 'الملف غير موجود على الخادم';
        return 'خطأ من الخادم ($code)';
      default:
        return 'فشل التحميل';
    }
  }
}
