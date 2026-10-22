import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/draw_result.dart';
import '../models/lotto_game.dart';
import '../services/pattern_analyzer.dart';
import '../services/pcso_results_service.dart';

/// Live PCSO results for the selected game, with the patterns found in the
/// latest draw and in the previous draw day.
class LatestResultsScreen extends StatefulWidget {
  const LatestResultsScreen({super.key, this.initialGame = LottoGame.lotto642});

  final LottoGame initialGame;

  @override
  State<LatestResultsScreen> createState() => _LatestResultsScreenState();
}

class _LatestResultsScreenState extends State<LatestResultsScreen> {
  static const _accent = Color(0xFF6254DF);
  static const _refreshEvery = Duration(minutes: 2);

  final _service = PcsoResultsService();
  final _analyzer = const PatternAnalyzer();
  final Map<LottoGame, List<DrawResult>> _cache = {};

  late LottoGame _game = widget.initialGame;
  Timer? _timer;
  bool _loading = false;
  String? _error;
  DateTime? _updatedAt;
  DateTime? _searchStart;
  DateTime? _searchEnd;
  List<DrawResult> _searchedDraws = [];
  bool _searching = false;
  bool _hasSearched = false;
  String? _searchError;
  bool _loadingPatternActivity = false;
  String? _patternActivityError;
  Map<LottoGame, _PatternActivity> _patternActivity = {};

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    _searchEnd = end;
    _searchStart = end.subtract(const Duration(days: 30));
    _load();
    _loadPatternActivity();
    _timer = Timer.periodic(_refreshEvery, (_) => _load(silent: true));
  }



  @override
  void dispose() {
    _timer?.cancel();
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadPatternActivity() async {
    if (_loadingPatternActivity) return;
    setState(() {
      _loadingPatternActivity = true;
      _patternActivityError = null;
    });
    try {
      final today = DateTime.now();
      final end = DateTime(today.year, today.month, today.day);
      final start = end.subtract(const Duration(days: 30));
      // One unavailable game should not prevent the summary for the others.
      final resultsByGame = await Future.wait(
        LottoGame.values.map((game) async {
          try {
            final draws = await _service.fetchRange(
              game,
              startDate: start,
              endDate: end,
            );
            return MapEntry<LottoGame, List<DrawResult>>(game, draws);
          } catch (_) {
            return MapEntry<LottoGame, List<DrawResult>>(game, const <DrawResult>[]);
          }
        }),
      );
      final summary = <LottoGame, _PatternActivity>{};
      for (final result in resultsByGame) {
        final game = result.key;
        final draws = result.value;
        var drawsWithPatterns = 0;
        var totalTypes = 0;
        var fullDraws = 0;
        final typeCounts = <String, int>{};
        for (final draw in draws) {
          final report = _analyzer.analyze(draw.numbers);
          // Count each pattern TYPE once per draw (max 7), not every pair.
          final found = <String>[
            if (report.plusTwo.isNotEmpty) 'Plus 2',
            if (report.twins.isNotEmpty) 'Twin',
            if (report.reversed.isNotEmpty) 'Reversed',
            for (final e in report.plusSteps.entries)
              if (e.value.isNotEmpty) 'Plus ${e.key}',
            if (report.solo != null) 'Solo',
          ];
          if (found.isNotEmpty) drawsWithPatterns++;
          // A draw counts when all six numbers are accounted for by patterns,
          // whichever patterns they are (a solo number counts as the sixth).
          final covered = report.involved.length + (report.solo != null ? 1 : 0);
          final isFull = draw.numbers.isNotEmpty && covered >= draw.numbers.toSet().length;
          if (isFull) fullDraws++;
          totalTypes += found.length;
          for (final t in found) {
            typeCounts[t] = (typeCounts[t] ?? 0) + 1;
          }
        }
        summary[game] = _PatternActivity(
          totalDraws: draws.length,
          drawsWithPatterns: drawsWithPatterns,
          fullDraws: fullDraws,
          totalTypes: totalTypes,
          typeCounts: typeCounts,
        );
      }
      if (!mounted) return;
      setState(() => _patternActivity = summary);
    } on PcsoResultsException catch (e) {
      if (mounted) setState(() => _patternActivityError = e.message);
    } catch (e) {
      if (mounted) setState(() => _patternActivityError = 'Could not calculate the 30-day pattern summary.');
    } finally {
      if (mounted) setState(() => _loadingPatternActivity = false);
    }
  }

  /// All games that have draw data, ranked by average pattern types per draw.
  List<MapEntry<LottoGame, _PatternActivity>> _topPatternGames() {
    final entries = _patternActivity.entries
        .where((entry) => entry.value.totalDraws > 0)
        .toList();
    entries.sort((a, b) {
      final c = b.value.fullRate.compareTo(a.value.fullRate);
      if (c != 0) return c;
      final d = b.value.avgTypes.compareTo(a.value.avgTypes);
      if (d != 0) return d;
      return b.value.totalDraws.compareTo(a.value.totalDraws);
    });
    return entries;
  }

  Future<void> _load({bool silent = false}) async {
    if (_loading) return;
    final game = _game;
    if (!silent || !_cache.containsKey(game)) setState(() => _loading = true);
    try {
      final results = await _service.fetchRecent(game);
      if (!mounted) return;
      setState(() {
        _cache[game] = results;
        if (game == _game) {
          _error = null;
          _updatedAt = DateTime.now();
        }
      });
    } on PcsoResultsException catch (e) {
      // Keep showing the last good data on a failed background refresh.
      if (mounted && game == _game && !(silent && _cache.containsKey(game))) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectGame(LottoGame game) {
    if (game == _game) return;
    setState(() {
      _game = game;
      _error = null;
      _updatedAt = _cache.containsKey(game) ? _updatedAt : null;
      _searchedDraws = [];
      _hasSearched = false;
      _searchError = null;
    });
    _load();
  }

  Future<void> _pickSearchDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _searchStart : _searchEnd) ??
        (isStart ? now.subtract(const Duration(days: 30)) : now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: isStart ? 'Select start date' : 'Select end date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _searchStart = picked;
        if (_searchEnd != null && _searchEnd!.isBefore(picked)) {
          _searchEnd = picked;
        }
      } else {
        _searchEnd = picked;
        if (_searchStart != null && _searchStart!.isAfter(picked)) {
          _searchStart = picked;
        }
      }
      _searchError = null;
    });
  }

  Future<void> _searchPreviousDraws() async {
    final now = DateTime.now();
    final start = _searchStart ?? DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
    final end = _searchEnd ?? DateTime(now.year, now.month, now.day);
    if (start.isAfter(end)) {
      setState(() => _searchError = 'Start date must be on or before end date.');
      return;
    }
    setState(() {
      _searching = true;
      _hasSearched = true;
      _searchError = null;
      _searchedDraws = [];
    });
    try {
      final results = await _service.fetchRange(_game, startDate: start, endDate: end);
      if (!mounted) return;
      setState(() => _searchedDraws = results);
    } on PcsoResultsException catch (e) {
      if (mounted) setState(() => _searchError = e.message);
    } catch (e) {
      if (mounted) setState(() => _searchError = 'Could not search these dates. Please try again.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  String _shortDate(DateTime? d) {
    if (d == null) return 'Choose date';
    return '${_mo[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _openOfficial() async {
    final ok = await launchUrl(PcsoResultsService.pageUri,
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open PCSO results.')),
      );
    }
  }

  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _mo = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _dateLabel(DateTime d) =>
      '${_wd[d.weekday - 1]}, ${_mo[d.month - 1]} ${d.day}, ${d.year}';

  String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final draws = _cache[_game] ?? const <DrawResult>[];


    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primaryContainer,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '7',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(child: Text('Latest Results')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Open official PCSO page',
            onPressed: _openOfficial,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                children: [
                  Row(
                    children: [
                      const _LiveDot(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _updatedAt == null
                              ? 'Connecting to PCSO…'
                              : 'Live · updated ${_two(_updatedAt!.hour)}:${_two(_updatedAt!.minute)} · pull to refresh',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                      if (_loading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in LottoGame.values)
                        ChoiceChip(
                          label: Text(g.displayName),
                          selected: g == _game,
                          onSelected: (_) => _selectGame(g),
                          selectedColor: context.lc.tint,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _patternActivityCard(theme, muted),
                  const SizedBox(height: 18),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Search Previous Draw Dates',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('Choose a date range to find historical ${_game.displayName} results.',
                              style: TextStyle(color: muted, fontSize: 12, height: 1.4)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _searching ? null : () => _pickSearchDate(isStart: true),
                                  icon: const Icon(Icons.calendar_today_rounded, size: 17),
                                  label: Text('From\n${_shortDate(_searchStart)}', textAlign: TextAlign.left),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _searching ? null : () => _pickSearchDate(isStart: false),
                                  icon: const Icon(Icons.event_rounded, size: 17),
                                  label: Text('To\n${_shortDate(_searchEnd)}', textAlign: TextAlign.left),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _searching ? null : _searchPreviousDraws,
                              icon: _searching
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.search_rounded),
                              label: Text(_searching ? 'Searching…' : 'Search Results'),
                              style: FilledButton.styleFrom(backgroundColor: _accent),
                            ),
                          ),
                          if (_searchError != null) ...[
                            const SizedBox(height: 12),
                            Text(_searchError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                          ],
                          if (_hasSearched && !_searching && _searchError == null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _searchedDraws.isEmpty
                                  ? 'No results found for the selected dates.'
                                  : '${_searchedDraws.length} draw${_searchedDraws.length == 1 ? '' : 's'} found',
                              style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_hasSearched && _searchedDraws.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (var i = 0; i < _searchedDraws.length; i++) ...[
                      _drawCard('Historical draw ${i + 1}', _searchedDraws[i]),
                      if (i < _searchedDraws.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                  const SizedBox(height: 16),
                  if (_error != null && draws.isEmpty)
                    _ErrorCard(message: _error!, onRetry: _load, onOpen: _openOfficial)
                  else if (draws.isEmpty && _loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (draws.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          'No ${_game.displayName} draws in the last 10 days.',
                          style: TextStyle(color: muted),
                        ),
                      ),
                    )
                  else ...[
                    _drawCard('Latest draw', draws.first),
                    if (draws.length > 1) ...[
                      const SizedBox(height: 14),
                      _drawCard(_previousLabel(draws), draws[1]),
                    ],
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.lc.neutralFill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Results are read from the official PCSO results page and refresh every 2 minutes. PCSO usually posts after the 9 PM draw. Always confirm winning numbers with PCSO. Patterns are shown for reference only; draws are random and patterns do not predict future results.',
                      style: TextStyle(color: context.lc.muted, fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _patternActivityCard(ThemeData theme, Color muted) {
    final top = _topPatternGames();
    return Card(
      color: context.lc.tint,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, color: context.lc.accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('30-Day Pattern Activity',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Compares how often all six numbers of a draw belonged to a pattern across the five jackpot games.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            if (_loadingPatternActivity && _patternActivity.isEmpty)
              const LinearProgressIndicator(minHeight: 3)
            else if (_patternActivityError != null && _patternActivity.isEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(_patternActivityError!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12))),
                  TextButton(onPressed: _loadPatternActivity, child: const Text('Retry')),
                ],
              )
            else if (top.isEmpty)
              Text('No historical draw data is available to compare yet.', style: TextStyle(color: muted, fontSize: 12))
            else ...[
              for (var i = 0; i < top.length; i++) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.lc.surface.withValues(alpha: .75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle),
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(top[i].key.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(top[i].value.subtitle,
                                style: TextStyle(color: muted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${(top[i].value.fullRate * 100).round()}%',
                              style: const TextStyle(color: _accent, fontSize: 18, fontWeight: FontWeight.w900)),
                          Text('fully patterned', style: TextStyle(color: muted, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (i < top.length - 1) const SizedBox(height: 8),
              ],
              const SizedBox(height: 10),
              Text(
                'Percentage of draws where every number was part of a detected pattern (any patterns; a solo number counts). This is a historical summary, not a prediction of future winning numbers.',
                style: TextStyle(color: muted, fontSize: 11, height: 1.4),
              ),
              if (_loadingPatternActivity) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _previousLabel(List<DrawResult> draws) {
    final latest = draws.first.drawDate;
    final prev = draws[1].drawDate;
    return latest.difference(prev).inDays == 1 ? 'Previous day' : 'Previous draw';
  }

  Widget _drawCard(String title, DrawResult draw) {
    final report = _analyzer.analyze(draw.numbers);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    String pairText(List<({int first, int second})> pairs) =>
        pairs.map((p) => '${_two(p.first)}–${_two(p.second)}').join(', ');

    final chips = <String>[
      if (report.plusTwo.isNotEmpty) 'Plus 2: ${pairText(report.plusTwo)}',
      if (report.twins.isNotEmpty) 'Twin: ${report.twins.map(_two).join(', ')}',
      if (report.reversed.isNotEmpty) 'Reversed: ${pairText(report.reversed)}',
      for (final e in report.plusSteps.entries)
        if (e.value.isNotEmpty) 'Plus ${e.key}: ${pairText(e.value)}',
      if (report.solo != null) 'Solo pattern: ${_two(report.solo!)}',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title.toUpperCase(),
                    style: const TextStyle(
                        color: _accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                const Spacer(),
                Text(_dateLabel(draw.drawDate), style: TextStyle(color: muted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in draw.numbers)
                  _Ball(
                    number: _two(n),
                    highlighted: report.involved.contains(n) || n == report.solo),
              ],
            ),
            const SizedBox(height: 14),
            if (chips.isEmpty)
              Text('No patterns in this draw', style: TextStyle(color: muted, fontSize: 12))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in chips)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.lc.tint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(c,
                          style: TextStyle(
                              color: context.lc.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            if (draw.jackpot != null) ...[
              const SizedBox(height: 12),
              Text(
                'Jackpot ₱${draw.jackpot}'
                '${draw.winners == null ? '' : ' · ${draw.winners} winner${draw.winners == 1 ? '' : 's'}'}',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PatternActivity {
  const _PatternActivity({
    required this.totalDraws,
    required this.drawsWithPatterns,
    required this.fullDraws,
    required this.totalTypes,
    required this.typeCounts,
  });

  final int totalDraws;
  final int drawsWithPatterns;

  /// Draws where all six numbers belong to some pattern (a solo counts).
  final int fullDraws;

  /// Sum over draws of how many different pattern types each draw had.
  final int totalTypes;

  /// How many draws contained each pattern type (e.g. 'Plus 20' -> 9).
  final Map<String, int> typeCounts;

  double get fullRate => totalDraws == 0 ? 0 : fullDraws / totalDraws;

  /// Average number of different pattern types per draw (0-7).
  double get avgTypes => totalDraws == 0 ? 0 : totalTypes / totalDraws;

  String get subtitle =>
      '$fullDraws of $totalDraws draws had all six numbers in patterns · avg ${avgTypes.toStringAsFixed(1)} patterns per draw';
}

class _Ball extends StatelessWidget {
  const _Ball({required this.number, required this.highlighted});

  final String number;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlighted ? const Color(0xFF6254DF) : context.lc.ballFill,
      ),
      child: Text(
        number,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: highlighted ? Colors.white : context.lc.strongText,
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
        child: Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle),
        ),
      );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry, required this.onOpen});

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
                OutlinedButton(onPressed: onOpen, child: const Text('Open PCSO page')),
              ]),
            ],
          ),
        ),
      );
}
