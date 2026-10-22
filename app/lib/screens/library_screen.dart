import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../core/theme.dart';
import '../models/bookmark.dart';
import '../services/data_repository.dart';
import '../services/download_service.dart';
import '../services/player_controller.dart';
import '../state/library_state.dart';
import '../state/settings_state.dart';
import '../widgets/episode_tile.dart';
import 'player_screen.dart';

/// محفوظاتي: المفضلة والعلامات والحلقات المحمّلة.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'محفوظاتي',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 22),
            ),
          ),
          const TabBar(
            indicatorColor: AppColors.gold,
            labelColor: AppColors.gold,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'المفضلة'),
              Tab(text: 'العلامات'),
              Tab(text: 'المحمّلة'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _FavoritesTab(),
                _BookmarksTab(),
                _DownloadsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openEpisode(
  BuildContext context,
  String episodeId, {
  Duration? at,
}) async {
  final episode = DataRepository.instance.episodeById(episodeId);
  if (episode == null) return;
  await PlayerController.instance.open(episode, startAt: at);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const PlayerScreen()),
  );
  if (!context.mounted) return;
  context.read<LibraryState>().refreshProgress();
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final episodes = library.favoriteEpisodes;

    if (episodes.isEmpty) {
      return const _Empty(
        icon: Icons.bookmark_border_rounded,
        message: 'لم تضف أي حلقة إلى المفضلة بعد.\n'
            'اضغط على أيقونة العلامة في أي حلقة لإضافتها هنا.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: episodes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => EpisodeTile(
        episode: episodes[i],
        onTap: () => _openEpisode(context, episodes[i].id),
      ),
    );
  }
}

class _BookmarksTab extends StatelessWidget {
  const _BookmarksTab();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final arabicDigits =
        context.select<SettingsState, bool>((s) => s.arabicDigits);
    final bookmarks = library.bookmarks;

    if (bookmarks.isEmpty) {
      return const _Empty(
        icon: Icons.add_location_alt_outlined,
        message: 'لا توجد علامات.\n'
            'أثناء الاستماع اضغط «علامة» لحفظ اللحظة مع ملاحظتك.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: bookmarks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final bookmark = bookmarks[i];
        final episode = DataRepository.instance.episodeById(bookmark.episodeId);
        final theme = Theme.of(context);

        return Dismissible(
          key: ValueKey(bookmark.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.delete_outline_rounded,
                color: theme.colorScheme.error),
          ),
          onDismissed: (_) => library.removeBookmark(bookmark.id),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.gold.withValues(alpha: 0.18),
                child: const Icon(Icons.place_rounded,
                    color: AppColors.gold, size: 20),
              ),
              title: Text(
                bookmark.note.isEmpty ? 'بلا ملاحظة' : bookmark.note,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontStyle: bookmark.note.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: bookmark.note.isEmpty
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                      : null,
                ),
              ),
              subtitle: Text(
                '${episode?.title ?? bookmark.episodeId} • '
                '${formatDuration(bookmark.positionObject, arabicDigits: arabicDigits)}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'تعديل الملاحظة',
                onPressed: () => _editNote(context, library, bookmark),
              ),
              onTap: () => _openEpisode(
                context,
                bookmark.episodeId,
                at: bookmark.positionObject,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editNote(
    BuildContext context,
    LibraryState library,
    Bookmark bookmark,
  ) async {
    final controller = TextEditingController(text: bookmark.note);
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الملاحظة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'ملاحظتك'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (note != null) await library.updateBookmarkNote(bookmark.id, note);
  }
}

class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final downloads = context.watch<DownloadService>();
    final episodes = library.allEpisodes
        .where((e) => downloads.isDownloaded(e.id))
        .toList();

    if (episodes.isEmpty) {
      return const _Empty(
        icon: Icons.download_outlined,
        message: 'لا توجد حلقات محمّلة.\n'
            'حمّل الحلقات لتستمع إليها دون إنترنت.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: FutureBuilder<int>(
            future: downloads.usedBytes(),
            builder: (context, snapshot) => Row(
              children: [
                const Icon(Icons.sd_storage_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${toArabicDigits('${episodes.length}')} حلقة • '
                  '${formatBytes(snapshot.data ?? 0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: episodes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => EpisodeTile(
              episode: episodes[i],
              onTap: () => _openEpisode(context, episodes[i].id),
            ),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.22)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
