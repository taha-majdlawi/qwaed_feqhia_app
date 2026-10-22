import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../screens/player_screen.dart';
import '../services/player_controller.dart';

/// شريط تشغيل مصغّر يظهر فوق شريط التنقّل متى كانت هناك حلقة مفتوحة.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final episode = player.episode;
    if (episode == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? AppColors.darkSurface
          : Colors.white.withValues(alpha: 0.96),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PlayerScreen()),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<Duration>(
              stream: player.positionStream,
              builder: (context, snapshot) {
                final total = player.duration.inMilliseconds;
                final pos = (snapshot.data ?? Duration.zero).inMilliseconds;
                return LinearProgressIndicator(
                  value: total > 0 ? (pos / total).clamp(0.0, 1.0) : 0,
                  minHeight: 2,
                  backgroundColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.gold),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: AppColors.gold.withValues(alpha: 0.18),
                    ),
                    child: const Icon(Icons.graphic_eq_rounded,
                        size: 20, color: AppColors.gold),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          episode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _CurrentParagraphLine(player: player),
                      ],
                    ),
                  ),
                  if (player.isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: player.playPause,
                      iconSize: 34,
                      color: theme.colorScheme.primary,
                      icon: Icon(
                        player.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentParagraphLine extends StatelessWidget {
  const _CurrentParagraphLine({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: player.currentParagraph,
      builder: (context, index, _) {
        final paragraphs = player.transcript?.paragraphs;
        final text = (paragraphs != null && index >= 0 && index < paragraphs.length)
            ? paragraphs[index].text
            : (player.error ?? 'اضغط للاستماع ومتابعة النص');
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: player.error != null
                ? theme.colorScheme.error
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        );
      },
    );
  }
}
