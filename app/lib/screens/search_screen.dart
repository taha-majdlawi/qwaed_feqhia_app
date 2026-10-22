import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../core/theme.dart';
import '../models/bookmark.dart';
import '../services/data_repository.dart';
import '../services/player_controller.dart';
import '../services/storage_service.dart';
import '../state/library_state.dart';
import '../state/settings_state.dart';
import 'player_screen.dart';

/// بحث شامل في نصوص الحلقات كلها، يتجاهل التشكيل وصور الهمزة.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final DataRepository _repo = DataRepository.instance;

  Timer? _debounce;
  bool _indexing = false;
  double _indexProgress = 0;
  List<SearchHit> _hits = const [];
  String _activeQuery = '';
  String? _episodeFilter;
  List<String> _history = const [];

  @override
  void initState() {
    super.initState();
    _history = StorageService.instance.searchHistory;
    _prepareIndex();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _prepareIndex() async {
    if (_repo.isSearchReady) return;
    setState(() => _indexing = true);
    await _repo.loadAllTranscripts(onProgress: (done, total) {
      if (mounted) setState(() => _indexProgress = done / total);
    });
    if (mounted) setState(() => _indexing = false);
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () => _run(value));
  }

  void _run(String value) {
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _hits = const [];
        _activeQuery = '';
      });
      return;
    }
    setState(() {
      _activeQuery = query;
      _hits = _repo.search(query, episodeFilter: _episodeFilter);
    });
  }

  Future<void> _rememberQuery(String query) async {
    final updated = [query, ..._history.where((h) => h != query)].take(8).toList();
    _history = updated;
    await StorageService.instance.setSearchHistory(updated);
  }

  Future<void> _openHit(SearchHit hit) async {
    await _rememberQuery(_activeQuery);
    final episode = _repo.episodeById(hit.episodeId);
    if (episode == null) return;
    await PlayerController.instance.open(
      episode,
      startAt: Duration(milliseconds: (hit.start * 1000).round()),
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerScreen()),
    );
    if (!mounted) return;
    context.read<LibraryState>().refreshProgress();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arabicDigits = context.select<SettingsState, bool>(
      (s) => s.arabicDigits,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            children: [
              Text(
                'البحث في نصوص السلسلة',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
              ),
              const GoldDividerSpacer(),
              TextField(
                controller: _controller,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: _run,
                decoration: InputDecoration(
                  hintText: 'اكتب كلمة أو جملة… مثال: الضرر يزال',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            _run('');
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        if (_indexing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              children: [
                LinearProgressIndicator(value: _indexProgress),
                const SizedBox(height: 8),
                Text('جارٍ تجهيز فهرس البحث…',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        if (_activeQuery.isNotEmpty && !_indexing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: [
                Text(
                  _hits.isEmpty
                      ? 'لا نتائج'
                      : '${arabicDigits ? toArabicDigits('${_hits.length}') : _hits.length} نتيجة'
                          '${_hits.length >= 300 ? ' (أول ٣٠٠)' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (_episodeFilter != null)
                  ActionChip(
                    avatar: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('إلغاء حصر الحلقة'),
                    onPressed: () {
                      setState(() => _episodeFilter = null);
                      _run(_activeQuery);
                    },
                  ),
              ],
            ),
          ),
        Expanded(
          child: _activeQuery.isEmpty
              ? _SearchIdleView(
                  history: _history,
                  onPick: (q) {
                    _controller.text = q;
                    _run(q);
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: _hits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _HitCard(
                    hit: _hits[i],
                    arabicDigits: arabicDigits,
                    onTap: () => _openHit(_hits[i]),
                    onLimitToEpisode: () {
                      setState(() => _episodeFilter = _hits[i].episodeId);
                      _run(_activeQuery);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class GoldDividerSpacer extends StatelessWidget {
  const GoldDividerSpacer({super.key});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6, bottom: 12),
        width: 110,
        height: 2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: LinearGradient(
            colors: [
              AppColors.gold.withValues(alpha: 0),
              AppColors.gold,
              AppColors.gold.withValues(alpha: 0),
            ],
          ),
        ),
      );
}

class _HitCard extends StatelessWidget {
  const _HitCard({
    required this.hit,
    required this.arabicDigits,
    required this.onTap,
    required this.onLimitToEpisode,
  });

  final SearchHit hit;
  final bool arabicDigits;
  final VoidCallback onTap;
  final VoidCallback onLimitToEpisode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // مقتطف حول موضع المطابقة.
    const window = 110;
    final start = (hit.matchStart - window).clamp(0, hit.text.length);
    final end = (hit.matchEnd + window).clamp(0, hit.text.length);
    final prefix = hit.text.substring(start, hit.matchStart);
    final match = hit.text.substring(hit.matchStart, hit.matchEnd);
    final suffix = hit.text.substring(hit.matchEnd, end);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLimitToEpisode,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    child: Text(
                      'الحلقة ${arabicDigits ? toArabicDigits('${hit.episodeNumber}') : hit.episodeNumber}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.play_circle_outline_rounded,
                      size: 15,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    formatDuration(
                      Duration(milliseconds: (hit.start * 1000).round()),
                      arabicDigits: arabicDigits,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                textAlign: TextAlign.justify,
                textDirection: TextDirection.rtl,
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontSize: 16.5,
                    height: 1.85,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.82),
                  ),
                  children: [
                    if (start > 0) const TextSpan(text: '… '),
                    TextSpan(text: prefix),
                    TextSpan(
                      text: match,
                      style: TextStyle(
                        backgroundColor:
                            AppColors.gold.withValues(alpha: 0.34),
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(text: suffix),
                    if (end < hit.text.length) const TextSpan(text: ' …'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchIdleView extends StatelessWidget {
  const _SearchIdleView({required this.history, required this.onPick});

  final List<String> history;
  final void Function(String) onPick;

  static const _suggestions = [
    'الضرر يزال',
    'اليقين لا يزول بالشك',
    'المشقة تجلب التيسير',
    'الأمور بمقاصدها',
    'العادة محكمة',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (history.isNotEmpty) ...[
          Text('عمليات بحث سابقة', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in history)
                ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 16),
                  label: Text(q),
                  onPressed: () => onPick(q),
                ),
            ],
          ),
          const SizedBox(height: 22),
        ],
        Text('قواعد يكثر البحث عنها', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in _suggestions)
              ActionChip(
                label: Text(q),
                onPressed: () => onPick(q),
              ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'البحث يتجاهل التشكيل وصور الهمزة والتاء المربوطة، فـ«إلهي» و«الهي» سواء. '
                'اضغط مطوّلاً على أي نتيجة لحصر البحث في حلقتها.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.8,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
