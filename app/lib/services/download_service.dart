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
  Directory? _dir;

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

  Future<void> download(Episode episode) async {
    if (infoFor(episode.id).status == DownloadStatus.running) return;
    if (isDownloaded(episode.id)) return;

    final target = await localPath(episode);
    final temp = '$target.part';
    final token = CancelToken();
    _tokens[episode.id] = token;
    _state[episode.id] = const DownloadInfo(
      status: DownloadStatus.running,
    );
    notifyListeners();

    try {
      await _dio.download(
        remoteUri(episode).toString(),
        temp,
        cancelToken: token,
        options: Options(followRedirects: true, receiveTimeout: null),
        onReceiveProgress: (received, total) {
          _state[episode.id] = DownloadInfo(
            status: DownloadStatus.running,
            progress: total > 0 ? received / total : 0,
            received: received,
            total: total,
          );
          notifyListeners();
        },
      );
      await File(temp).rename(target);
      _state[episode.id] = const DownloadInfo(status: DownloadStatus.done);
    } on DioException catch (e) {
      await _safeDelete(temp);
      _state[episode.id] = DownloadInfo(
        status: CancelToken.isCancel(e)
            ? DownloadStatus.none
            : DownloadStatus.failed,
        error: CancelToken.isCancel(e) ? null : _messageFor(e),
      );
    } catch (e) {
      await _safeDelete(temp);
      _state[episode.id] =
          DownloadInfo(status: DownloadStatus.failed, error: '$e');
    } finally {
      _tokens.remove(episode.id);
      notifyListeners();
    }
  }

  void cancel(String episodeId) {
    _tokens[episodeId]?.cancel('أُلغي التحميل');
  }

  Future<void> delete(Episode episode) async {
    cancel(episode.id);
    await _safeDelete(await localPath(episode));
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
