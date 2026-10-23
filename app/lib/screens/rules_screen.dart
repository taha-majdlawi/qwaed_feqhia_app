import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/arabic.dart';
import '../core/theme.dart';
import '../widgets/mosque_background.dart';
import '../models/rule.dart';
import '../services/data_repository.dart';
import '../services/player_controller.dart';
import '../state/library_state.dart';
import '../state/settings_state.dart';
import 'player_screen.dart';

/// فهرس القواعد والعبارات التي يقتبسها الشيخ بين «» في السلسلة،
/// مرتّبة بالأكثر وروداً، مع الانتقال إلى أي موضع ورود.
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  final DataRepository _repo = DataRepository.instance;
  final TextEditingController _filter = TextEditingController();

  bool _loading = false;
  double _progress = 0;
  List<FiqhRule> _rules = const [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    if (!_repo.isSearchReady) {
      setState(() => _loading = true);
      await _repo.loadAllTranscripts(onProgress: (done, total) {
        if (mounted) setState(() => _progress = done / total);
      });
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _rules = _repo.rules();
    });
  }

  List<FiqhRule> get _visible {
    final needle = normalizeArabic(_query);
    if (needle.isEmpty) return _rules;
    return _rules.where((r) => r.normalized.contains(needle)).toList();
  }

  Future<void> _openOccurrence(RuleOccurrence occurrence) async {
    final episode = _repo.episodeById(occurrence.episodeId);
    if (episode == null) return;
    unawaited(PlayerController.instance.open(
      episode,
      startAt: Duration(milliseconds: (occurrence.start * 1000).round()),
    ));
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlayerScreen()),
    );
    if (!mounted) return;
    context.read<LibraryState>().refreshProgress();
  }

  Future<void> _showOccurrences(FiqhRule rule) async {
    final arabicDigits =
        context.read<SettingsState>().arabicDigits;

    final chosen = await showModalBottomSheet<RuleOccurrence>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OccurrencesSheet(
        rule: rule,
        arabicDigits: arabicDigits,
      ),
    );
    if (chosen != null) await _openOccurrence(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arabicDigits =
        context.select<SettingsState, bool>((s) => s.arabicDigits);
    final rules = _visible;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            children: [
              Text(
                'فهرس القواعد',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
              ),
              const GoldDivider(width: 110, margin: EdgeInsets.only(top: 6, bottom: 10)),
              Text(
                'القواعد والعبارات التي نُقلت في السلسلة، الأكثر وروداً أولاً',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _filter,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'تصفية القواعد…',
                  prefixIcon: const Icon(Icons.filter_alt_outlined),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _filter.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
        if (_loading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 8),
                Text('جارٍ استخراج القواعد من النصوص…',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  '${digits('${rules.length}', arabic: arabicDigits)} قاعدة',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        Expanded(
          child: rules.isEmpty && !_loading
              ? Center(
                  child: Text(
                    'لا توجد قاعدة مطابقة',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: rules.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _RuleCard(
                    rule: rules[i],
                    rank: i + 1,
                    arabicDigits: arabicDigits,
                    onTap: () => _showOccurrences(rules[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.rank,
    required this.arabicDigits,
    required this.onTap,
  });

  final FiqhRule rule;
  final int rank;
  final bool arabicDigits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final episodes = rule.episodeNumbers;
    // القواعد الكبرى تتكرّر كثيراً؛ نبرزها.
    final prominent = rule.count >= 10;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '«${rule.text}»',
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontSize: prominent ? 21 : 18,
                        height: 1.8,
                        fontWeight:
                            prominent ? FontWeight.w700 : FontWeight.w400,
                        color: prominent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.gold.withValues(alpha: 0.20),
                    ),
                    child: Text(
                      '×${digits('${rule.count}', arabic: arabicDigits)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.brightness == Brightness.dark
                            ? AppColors.goldLight
                            : AppColors.green,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.library_books_outlined,
                      size: 14,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _episodesLabel(episodes),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded,
                      size: 20,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _episodesLabel(List<int> episodes) {
    final shown = episodes.take(8).map(
          (n) => digits('$n', arabic: arabicDigits),
        );
    final label = shown.join('، ');
    final more = episodes.length - 8;
    if (more > 0) {
      return 'الحلقات: $label وغيرها (${digits('$more', arabic: arabicDigits)})';
    }
    return episodes.length == 1 ? 'الحلقة $label' : 'الحلقات: $label';
  }
}

class _OccurrencesSheet extends StatelessWidget {
  const _OccurrencesSheet({required this.rule, required this.arabicDigits});

  final FiqhRule rule;
  final bool arabicDigits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...rule.occurrences]..sort((a, b) {
        final byEpisode = a.episodeNumber.compareTo(b.episodeNumber);
        return byEpisode != 0 ? byEpisode : a.start.compareTo(b.start);
      });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
            child: Text(
              '«${rule.text}»',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 20,
                height: 1.8,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Text(
            'وردت ${digits('${rule.count}', arabic: arabicDigits)} مرة',
            style: theme.textTheme.bodySmall,
          ),
          const GoldDivider(width: 90),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final occurrence = sorted[i];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.pop(context, occurrence),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
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
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.12),
                                ),
                                child: Text(
                                  'الحلقة ${digits('${occurrence.episodeNumber}', arabic: arabicDigits)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.play_circle_outline_rounded,
                                  size: 15,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.5)),
                              const SizedBox(width: 4),
                              Text(
                                formatDuration(
                                  Duration(
                                      milliseconds:
                                          (occurrence.start * 1000).round()),
                                  arabicDigits: arabicDigits,
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            occurrence.context,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.justify,
                            style: TextStyle(
                              fontFamily: AppTheme.displayFont,
                              fontSize: 16,
                              height: 1.85,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.82),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
