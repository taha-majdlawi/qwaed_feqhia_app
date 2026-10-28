import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/arabic.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../models/episode.dart';
import '../services/data_repository.dart';
import '../services/download_service.dart';
import '../services/player_controller.dart';
import '../state/library_state.dart';
import '../state/settings_state.dart';
import '../widgets/episode_tile.dart';
import '../widgets/mosque_background.dart';

/// شاشة الاستماع: النص الموقوت يتتبّع الصوت، مع أدوات التحكّم كاملة.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _paragraphKeys = {};

  PlayerController get _player => PlayerController.instance;

  bool _userScrolling = false;
  Timer? _userScrollTimer;
  int? _highlightedSearchIndex;

  @override
  void initState() {
    super.initState();
    _player.currentParagraph.addListener(_onParagraphChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToParagraph(_player.currentParagraph.value, animate: false);
    });
  }

  @override
  void dispose() {
    _player.currentParagraph.removeListener(_onParagraphChanged);
    _userScrollTimer?.cancel();
    _scrollController.dispose();
    _player.saveNow();
    super.dispose();
  }

  void _onParagraphChanged() {
    if (!mounted) return;
    if (!context.read<SettingsState>().autoScroll) return;
    if (_userScrolling) return;
    _scrollToParagraph(_player.currentParagraph.value);
  }

  void _scrollToParagraph(int index, {bool animate = true}) {
    final key = _paragraphKeys[index];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: animate ? const Duration(milliseconds: 420) : Duration.zero,
      curve: Curves.easeOutCubic,
      alignment: 0.28,
    );
  }

  void _markUserScroll() {
    _userScrolling = true;
    _userScrollTimer?.cancel();
    _userScrollTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) _userScrolling = false;
    });
  }

  Future<void> _addBookmark() async {
    final episode = _player.episode;
    if (episode == null) return;
    final position = _player.position;
    final paragraphIndex = _player.currentParagraph.value;
    final controller = TextEditingController();

    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة علامة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عند الدقيقة ${formatDuration(position)} من ${episode.title}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'ملاحظة (اختياري)',
              ),
            ),
          ],
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

    if (note == null || !mounted) return;
    await context.read<LibraryState>().addBookmark(
          episodeId: episode.id,
          position: position.inMilliseconds / 1000,
          note: note,
          paragraphIndex: paragraphIndex >= 0 ? paragraphIndex : null,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('أُضيفت العلامة إلى محفوظاتك')),
    );
  }

  Future<void> _openInEpisodeSearch() async {
    final episode = _player.episode;
    final transcript = _player.transcript;
    if (episode == null || transcript == null) return;

    final index = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _InEpisodeSearchSheet(transcript: transcript),
    );
    if (index == null || !mounted) return;
    setState(() => _highlightedSearchIndex = index);
    await _player.seekToParagraph(index);
    _scrollToParagraph(index);
  }

  Future<void> _showSleepTimerSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => _SleepTimerSheet(player: _player),
    );
  }

  Future<void> _shareEpisodeText() async {
    final episode = _player.episode;
    if (episode == null) return;
    final text = await DataRepository.instance.loadPlainText(episode.id);
    final trimmed = text.length > 3000 ? '${text.substring(0, 3000)}…' : text;
    await SharePlus.instance.share(
      ShareParams(
        text: '${episode.title}\n${AppConstants.author}\n\n$trimmed',
        subject: episode.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final episode = player.episode;

    if (episode == null) {
      return const Scaffold(
        body: Center(child: Text('لم تُفتح أي حلقة بعد')),
      );
    }

    final library = context.watch<LibraryState>();
    final isFavorite = library.isFavorite(episode.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MosqueBackground(
        imageOpacity: 0.08,
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                episode: episode,
                isFavorite: isFavorite,
                onToggleFavorite: () => library.toggleFavorite(episode.id),
                onSearch: _openInEpisodeSearch,
                onSleepTimer: _showSleepTimerSheet,
                onShare: _shareEpisodeText,
                onMarkCompleted: () async {
                  await library.markCompleted(
                      episode, !library.isCompleted(episode.id));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(library.isCompleted(episode.id)
                          ? 'عُلّمت الحلقة كمكتملة'
                          : 'أُزيلت علامة الاكتمال'),
                    ),
                  );
                },
              ),
              Expanded(
                child: player.error != null
                    ? _ErrorView(message: player.error!, episode: episode)
                    : NotificationListener<UserScrollNotification>(
                        onNotification: (_) {
                          _markUserScroll();
                          return false;
                        },
                        child: _TranscriptView(
                          player: player,
                          scrollController: _scrollController,
                          paragraphKeys: _paragraphKeys,
                          highlightedSearchIndex: _highlightedSearchIndex,
                        ),
                      ),
              ),
              _ControlsPanel(
                player: player,
                onAddBookmark: _addBookmark,
                onFollowNow: () {
                  _userScrolling = false;
                  _scrollToParagraph(player.currentParagraph.value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== الشريط العلوي =====================

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.episode,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onSearch,
    required this.onSleepTimer,
    required this.onShare,
    required this.onMarkCompleted,
  });

  final Episode episode;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onSearch;
  final VoidCallback onSleepTimer;
  final VoidCallback onShare;
  final VoidCallback onMarkCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arabicDigits =
        context.select<SettingsState, bool>((s) => s.arabicDigits);
    final isDark = theme.brightness == Brightness.dark;
    final surface =
        isDark ? AppColors.darkBg : AppColors.cream;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      decoration: BoxDecoration(
        // تدرّج معتم يمنع مرور النص المتحرّك تحت العنوان.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [surface, surface, surface.withValues(alpha: 0)],
          stops: const [0, 0.78, 1],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
            tooltip: 'إغلاق',
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  digits(episode.title, arabic: arabicDigits),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 19),
                ),
                Text(
                  AppConstants.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSearch,
            tooltip: 'بحث داخل الحلقة',
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            onPressed: onToggleFavorite,
            tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
            icon: Icon(
              isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isFavorite ? AppColors.gold : null,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              switch (value) {
                case 'sleep':
                  onSleepTimer();
                case 'share':
                  onShare();
                case 'completed':
                  onMarkCompleted();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'sleep',
                child: ListTile(
                  leading: Icon(Icons.bedtime_outlined),
                  title: Text('مؤقّت النوم'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share_outlined),
                  title: Text('مشاركة نص الحلقة'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'completed',
                child: ListTile(
                  leading: Icon(Icons.task_alt_rounded),
                  title: Text('تبديل علامة الاكتمال'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===================== النص المتتبِّع =====================

class _TranscriptView extends StatelessWidget {
  const _TranscriptView({
    required this.player,
    required this.scrollController,
    required this.paragraphKeys,
    required this.highlightedSearchIndex,
  });

  final PlayerController player;
  final ScrollController scrollController;
  final Map<int, GlobalKey> paragraphKeys;
  final int? highlightedSearchIndex;

  @override
  Widget build(BuildContext context) {
    final transcript = player.transcript;
    if (player.isLoading || transcript == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final settings = context.watch<SettingsState>();
    final paragraphs = transcript.paragraphs;

    return SelectionArea(
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ValueListenableBuilder<int>(
          valueListenable: player.currentParagraph,
          builder: (context, activeIndex, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < paragraphs.length; i++)
                _ParagraphBlock(
                  key: paragraphKeys.putIfAbsent(i, GlobalKey.new),
                  paragraph: paragraphs[i],
                  active: i == activeIndex,
                  searchHighlighted: i == highlightedSearchIndex,
                  fontScale: settings.fontScale,
                  arabicDigits: settings.arabicDigits,
                  onTap: () => player.seekToParagraph(i),
                  onLongPress: () async {
                    await Clipboard.setData(
                        ClipboardData(text: paragraphs[i].text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('نُسخت الفقرة')),
                    );
                  },
                ),
              const SizedBox(height: 8),
              const Center(child: GoldDivider(width: 90)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParagraphBlock extends StatelessWidget {
  const _ParagraphBlock({
    super.key,
    required this.paragraph,
    required this.active,
    required this.searchHighlighted,
    required this.fontScale,
    required this.arabicDigits,
    required this.onTap,
    required this.onLongPress,
  });

  final Paragraph paragraph;
  final bool active;
  final bool searchHighlighted;
  final double fontScale;
  final bool arabicDigits;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final background = active
        ? AppColors.gold.withValues(alpha: isDark ? 0.18 : 0.20)
        : searchHighlighted
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            right: BorderSide(
              color: active ? AppColors.gold : Colors.transparent,
              width: 3.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  formatDuration(paragraph.startObject,
                      arabicDigits: arabicDigits),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: active
                        ? AppColors.gold
                        : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.graphic_eq_rounded,
                      size: 14, color: AppColors.gold),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              paragraph.text,
              textAlign: TextAlign.justify,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 19 * fontScale,
                height: 1.95,
                color: active
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.78),
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== لوحة التحكّم =====================

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({
    required this.player,
    required this.onAddBookmark,
    required this.onFollowNow,
  });

  final PlayerController player;
  final VoidCallback onAddBookmark;
  final VoidCallback onFollowNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final arabicDigits = context.select<SettingsState, bool>(
      (s) => s.arabicDigits,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProgressBar(player: player, arabicDigits: arabicDigits),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _SpeedButton(player: player, arabicDigits: arabicDigits),
              IconButton(
                tooltip: 'الفقرة السابقة',
                onPressed: player.previousParagraph,
                icon: const Icon(Icons.skip_previous_rounded, size: 30),
              ),
              IconButton(
                tooltip: 'إرجاع ١٠ ثوانٍ',
                onPressed: () =>
                    player.skip(const Duration(seconds: -10)),
                icon: const Icon(Icons.replay_10_rounded, size: 30),
              ),
              _PlayButton(player: player),
              IconButton(
                tooltip: 'تقديم ١٠ ثوانٍ',
                onPressed: () => player.skip(const Duration(seconds: 10)),
                icon: const Icon(Icons.forward_10_rounded, size: 30),
              ),
              IconButton(
                tooltip: 'الفقرة التالية',
                onPressed: player.nextParagraph,
                icon: const Icon(Icons.skip_next_rounded, size: 30),
              ),
              _RepeatButton(player: player),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: player.hasPrevious ? player.playPrevious : null,
                icon: const Icon(Icons.fast_rewind_rounded, size: 18),
                label: const Text('السابقة'),
              ),
              TextButton.icon(
                onPressed: onAddBookmark,
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: const Text('علامة'),
              ),
              TextButton.icon(
                onPressed: onFollowNow,
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('تتبّع'),
              ),
              TextButton.icon(
                onPressed: player.hasNext ? player.playNext : null,
                icon: const Icon(Icons.fast_forward_rounded, size: 18),
                label: const Text('التالية'),
              ),
            ],
          ),
          if (player.hasSleepTimer)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bedtime_rounded,
                      size: 15, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Text(
                    player.stopAtEndOfEpisode
                        ? 'سيتوقّف عند نهاية الحلقة'
                        : 'سيتوقّف بعد ${formatDuration(player.sleepRemaining ?? Duration.zero, arabicDigits: arabicDigits)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: player.cancelSleepTimer,
                    child: const Text('إلغاء'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatefulWidget {
  const _ProgressBar({required this.player, required this.arabicDigits});

  final PlayerController player;
  final bool arabicDigits;

  @override
  State<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<_ProgressBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.player.duration;

    return StreamBuilder<Duration>(
      stream: widget.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final maxSeconds = total.inMilliseconds / 1000;
        final value = _dragValue ??
            (position.inMilliseconds / 1000).clamp(0.0, maxSeconds <= 0 ? 0.0 : maxSeconds);

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                min: 0,
                max: maxSeconds <= 0 ? 1.0 : maxSeconds,
                value: value.clamp(0.0, maxSeconds <= 0 ? 1.0 : maxSeconds),
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) {
                  widget.player.seek(
                      Duration(milliseconds: (v * 1000).round()));
                  setState(() => _dragValue = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDuration(
                      Duration(milliseconds: (value * 1000).round()),
                      arabicDigits: widget.arabicDigits,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    formatDuration(total, arabicDigits: widget.arabicDigits),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    if (player.isLoading) {
      return const SizedBox(
        width: 62,
        height: 62,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
        ),
      );
    }

    return Container(
      width: 62,
      height: 62,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppColors.gold, AppColors.goldLight],
        ),
      ),
      child: IconButton(
        onPressed: player.playPause,
        iconSize: 38,
        color: AppColors.green,
        icon: Icon(
          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        ),
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.player, required this.arabicDigits});

  final PlayerController player;
  final bool arabicDigits;

  @override
  Widget build(BuildContext context) {
    final label = player.speed.toStringAsFixed(
      player.speed == player.speed.roundToDouble() ? 0 : 2,
    );
    return PopupMenuButton<double>(
      tooltip: 'سرعة التشغيل',
      onSelected: player.setSpeed,
      itemBuilder: (context) => [
        for (final speed in AppConstants.speeds)
          PopupMenuItem(
            value: speed,
            child: Text('×${arabicDigits ? toArabicDigits('$speed') : speed}'),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Text(
          '×${arabicDigits ? toArabicDigits(label) : label}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
    );
  }
}

class _RepeatButton extends StatelessWidget {
  const _RepeatButton({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final (icon, tooltip, active) = switch (player.repeatMode) {
      PlaybackRepeatMode.off => (Icons.repeat_rounded, 'بلا تكرار', false),
      PlaybackRepeatMode.episode => (Icons.repeat_on_rounded, 'تكرار الحلقة', true),
      PlaybackRepeatMode.paragraph => (Icons.repeat_one_on_rounded, 'تكرار الفقرة', true),
    };

    return IconButton(
      tooltip: tooltip,
      onPressed: player.cycleRepeatMode,
      icon: Icon(icon, color: active ? AppColors.gold : null),
    );
  }
}

// ===================== أوراق سفلية =====================

class _SleepTimerSheet extends StatelessWidget {
  const _SleepTimerSheet({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    const options = [5, 10, 15, 30, 45, 60];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('مؤقّت النوم',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final minutes in options)
                ActionChip(
                  label: Text('${toArabicDigits('$minutes')} دقيقة'),
                  onPressed: () {
                    player.startSleepTimer(Duration(minutes: minutes));
                    Navigator.pop(context);
                  },
                ),
              ActionChip(
                label: const Text('نهاية الحلقة'),
                onPressed: () {
                  player.sleepAtEndOfEpisode();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          TextButton(
            onPressed: () {
              player.cancelSleepTimer();
              Navigator.pop(context);
            },
            child: const Text('إيقاف المؤقّت'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InEpisodeSearchSheet extends StatefulWidget {
  const _InEpisodeSearchSheet({required this.transcript});

  final EpisodeTranscript transcript;

  @override
  State<_InEpisodeSearchSheet> createState() => _InEpisodeSearchSheetState();
}

class _InEpisodeSearchSheetState extends State<_InEpisodeSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  List<({int index, Paragraph paragraph})> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _run(String query) {
    final needle = normalizeArabic(query);
    if (needle.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    final hits = <({int index, Paragraph paragraph})>[];
    final paragraphs = widget.transcript.paragraphs;
    for (var i = 0; i < paragraphs.length; i++) {
      if (paragraphs[i].normalized.contains(needle)) {
        hits.add((index: i, paragraph: paragraphs[i]));
      }
    }
    setState(() => _results = hits);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _run,
                decoration: const InputDecoration(
                  hintText: 'ابحث في نص هذه الحلقة',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${toArabicDigits('${_results.length}')} نتيجة',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final hit = _results[i];
                  return ListTile(
                    title: Text(
                      hit.paragraph.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle:
                        Text(formatDuration(hit.paragraph.startObject)),
                    onTap: () => Navigator.pop(context, hit.index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.episode});

  final String message;
  final Episode episode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: PlayerController.instance.retry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      DownloadService.instance.download(episode),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('تحميل الحلقة'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DownloadButton(episode: episode),
          ],
        ),
      ),
    );
  }
}
