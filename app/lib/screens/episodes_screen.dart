import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/episode.dart';
import '../services/player_controller.dart';
import '../state/library_state.dart';
import '../state/settings_state.dart';
import '../widgets/episode_tile.dart';
import '../widgets/mosque_background.dart';
import 'player_screen.dart';

/// قائمة الحلقات مع التصفية والفرز ومتابعة الاستماع.
class EpisodesScreen extends StatefulWidget {
  const EpisodesScreen({super.key});

  @override
  State<EpisodesScreen> createState() => _EpisodesScreenState();
}

class _EpisodesScreenState extends State<EpisodesScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEpisode(Episode episode) async {
    // لا ننتظر تحميل الصوت: الشاشة تفتح فوراً وتعرض حالة التحميل بنفسها.
    unawaited(PlayerController.instance.open(episode));
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerScreen()),
    );
    if (!mounted) return;
    context.read<LibraryState>().refreshProgress();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final episodes = library.visibleEpisodes;

    if (!library.isReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = library.loadError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error, textAlign: TextAlign.center),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _Header(library: library)),
        SliverToBoxAdapter(
          child: _ContinueCard(onOpen: _openEpisode),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: library.setQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث برقم الحلقة أو عنوانها',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: library.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          library.setQuery('');
                        },
                      ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _FilterRow(library: library)),
        if (episodes.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              icon: Icons.filter_alt_off_rounded,
              message: 'لا توجد حلقات مطابقة لهذه التصفية',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            sliver: SliverList.separated(
              itemCount: episodes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => EpisodeTile(
                episode: episodes[i],
                onTap: () => _openEpisode(episodes[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.library});

  final LibraryState library;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arabicDigits = context.select<SettingsState, bool>(
      (s) => s.arabicDigits,
    );
    String number(int value) =>
        arabicDigits ? toArabicDigits('$value') : '$value';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            AppConstants.appName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 30,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            AppConstants.appSubtitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              color: AppColors.gold,
            ),
          ),
          const GoldDivider(width: 150),
          Text(
            AppConstants.author,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            AppConstants.authorTitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Stat(
                label: 'الحلقات',
                value: number(library.allEpisodes.length),
              ),
              _Stat(
                label: 'مكتملة',
                value: number(library.completedCount),
              ),
              _Stat(
                label: 'قيد الاستماع',
                value: number(library.inProgressCount),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.onOpen});

  final Future<void> Function(Episode) onOpen;

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryState>();
    final episode = library.continueListening;
    if (episode == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final arabicDigits =
        context.select<SettingsState, bool>((s) => s.arabicDigits);
    final progress = library.progressOf(episode.id);
    final remaining = Duration(
      seconds: ((progress?.duration ?? episode.duration) -
              (progress?.position ?? 0))
          .round(),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(episode),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  AppColors.gold.withValues(alpha: 0.18),
                  AppColors.green.withValues(alpha: 0.08),
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.play_circle_fill_rounded,
                    size: 44, color: AppColors.gold),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'متابعة الاستماع',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        digits(episode.title, arabic: arabicDigits),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'بقي ${describeDuration(remaining, arabicDigits: arabicDigits)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.library});

  final LibraryState library;

  static const _labels = {
    EpisodeFilter.all: 'الكل',
    EpisodeFilter.inProgress: 'قيد الاستماع',
    EpisodeFilter.completed: 'مكتملة',
    EpisodeFilter.notStarted: 'لم تبدأ',
    EpisodeFilter.downloaded: 'محمّلة',
  };

  static const _sortLabels = {
    EpisodeSort.byNumber: 'الترتيب التصاعدي',
    EpisodeSort.byNumberDesc: 'الترتيب التنازلي',
    EpisodeSort.byDuration: 'الأطول أولاً',
    EpisodeSort.recentlyPlayed: 'آخر ما استمعت إليه',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          for (final entry in _labels.entries)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(entry.value),
                selected: library.filter == entry.key,
                onSelected: (_) => library.setFilter(entry.key),
              ),
            ),
          const SizedBox(width: 4),
          PopupMenuButton<EpisodeSort>(
            tooltip: 'الفرز',
            icon: const Icon(Icons.sort_rounded),
            onSelected: library.setSort,
            itemBuilder: (context) => [
              for (final entry in _sortLabels.entries)
                PopupMenuItem(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(
                        library.sort == entry.key
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(entry.value),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 54,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
