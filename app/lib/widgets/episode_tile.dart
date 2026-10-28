import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../core/theme.dart';
import '../models/episode.dart';
import '../services/download_service.dart';
import '../services/player_controller.dart';
import '../state/library_state.dart';
import '../state/settings_state.dart';

/// بطاقة حلقة في القوائم.
class EpisodeTile extends StatelessWidget {
  const EpisodeTile({
    super.key,
    required this.episode,
    required this.onTap,
    this.showProgress = true,
  });

  final Episode episode;
  final VoidCallback onTap;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final library = context.watch<LibraryState>();
    final player = context.watch<PlayerController>();
    final useArabicDigits = context.select<SettingsState, bool>(
      (s) => s.arabicDigits,
    );

    final isCurrent = player.episode?.id == episode.id;
    final fraction = library.fractionOf(episode.id);
    final completed = library.isCompleted(episode.id);
    final isFavorite = library.isFavorite(episode.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _NumberBadge(
                    number: episode.number,
                    active: isCurrent,
                    completed: completed,
                    arabicDigits: useArabicDigits,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          digits(episode.title, arabic: useArabicDigits),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isCurrent
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55)),
                            const SizedBox(width: 4),
                            Text(
                              describeDuration(episode.durationObject,
                                  arabicDigits: useArabicDigits),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.notes_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55)),
                            const SizedBox(width: 4),
                            Text(
                              '${digits('${episode.paragraphCount}', arabic: useArabicDigits)} فقرة',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.65),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isFavorite
                        ? 'إزالة من المفضلة'
                        : 'إضافة إلى المفضلة',
                    onPressed: () => library.toggleFavorite(episode.id),
                    icon: Icon(
                      isFavorite
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: isFavorite
                          ? AppColors.gold
                          : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                  DownloadButton(episode: episode),
                ],
              ),
              if (showProgress && (fraction > 0 || completed)) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: completed ? 1 : fraction,
                          minHeight: 4,
                          backgroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.10),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            completed ? AppColors.greenSoft : AppColors.gold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      completed
                          ? 'تم الاستماع'
                          : '${digits('${(fraction * 100).round()}', arabic: useArabicDigits)}٪',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({
    required this.number,
    required this.active,
    required this.completed,
    required this.arabicDigits,
  });

  final int number;
  final bool active;
  final bool completed;
  final bool arabicDigits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = arabicDigits ? toArabicDigits('$number') : '$number';

    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: active
              ? [AppColors.gold, AppColors.goldLight]
              : [
                  theme.colorScheme.primary.withValues(alpha: 0.14),
                  theme.colorScheme.primary.withValues(alpha: 0.06),
                ],
        ),
        border: Border.all(
          color: active
              ? AppColors.gold
              : theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: completed && !active
          ? const Icon(Icons.check_rounded,
              size: 22, color: AppColors.greenSoft)
          : Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: active ? AppColors.green : theme.colorScheme.primary,
              ),
            ),
    );
  }
}

/// زر التحميل/الإلغاء/الحذف لحلقة واحدة.
class DownloadButton extends StatelessWidget {
  const DownloadButton({super.key, required this.episode});

  final Episode episode;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الملف المحمّل؟'),
        content: Text(
          'سيُحذف صوت «${episode.title}» من الجهاز، ويبقى التشغيل متاحاً عبر الإنترنت.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await DownloadService.instance.delete(episode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadService>();
    final info = downloads.infoFor(episode.id);
    final theme = Theme.of(context);

    switch (info.status) {
      case DownloadStatus.running:
        return IconButton(
          tooltip: 'إلغاء التحميل',
          onPressed: () => downloads.cancel(episode.id),
          icon: SizedBox(
            width: 22,
            height: 22,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: info.progress > 0 ? info.progress : null,
                  strokeWidth: 2.4,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
                const Icon(Icons.close_rounded, size: 12),
              ],
            ),
          ),
        );
      case DownloadStatus.done:
        return IconButton(
          tooltip: 'محمّلة — اضغط للحذف',
          onPressed: () => _confirmDelete(context),
          icon: const Icon(Icons.offline_pin_rounded,
              color: AppColors.greenSoft),
        );
      case DownloadStatus.failed:
        return IconButton(
          tooltip: info.error ?? 'فشل التحميل — أعد المحاولة',
          onPressed: () => downloads.download(episode),
          icon: Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
        );
      case DownloadStatus.none:
        return IconButton(
          tooltip: 'تحميل للاستماع دون إنترنت',
          onPressed: () async {
            await downloads.download(episode);
            if (downloads.isDownloaded(episode.id)) {
              await PlayerController.instance.switchToLocalIfPossible(episode);
            }
          },
          icon: Icon(
            Icons.download_rounded,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        );
    }
  }
}
