import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/draw_result.dart';
import '../models/lotto_game.dart';
import '../services/pattern_analyzer.dart';
import '../services/entitlement_service.dart';
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
  bool _accessChecking = true;
  bool _accessAllowed = false;
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
    _checkAccess();
  }


  Future<void> _checkAccess() async {
    try {
      final allowed = await EntitlementService.instance.canOpenPremiumFeature();
      if (!mounted) return;
      setState(() { _accessAllowed = allowed; _accessChecking = false; });
      if (!allowed) return;
      _load();
      _loadPatternActivity();
      // "Live": re-check PCSO every couple of minutes while this tab is open.
      _timer = Timer.periodic(_refreshEvery, (_) => _load(silent: true));
    } catch (_) {
      if (mounted) setState(() { _accessAllowed = false; _accessChecking = false; });
    }
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
        var patternMatches = 0;
        for (final draw in draws) {
          final report = _analyzer.analyze(draw.numbers);
          final matches = report.plusTwo.length +
              report.twins.length +
              report.reversed.length +
              report.plusSteps.values.fold<int>(0, (sum, pairs) => sum + pairs.length) +
              (report.hasConsecutive ? 1 : 0) +
              (report.solo != null ? 1 : 0);
          if (matches > 0) drawsWithPatterns++;
          patternMatches += matches;
        }
        summary[game] = _PatternActivity(
          totalDraws: draws.length,
          drawsWithPatterns: drawsWithPatterns,
          patternMatches: patternMatches,
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

  List<MapEntry<LottoGame, _PatternActivity>> _topPatternGames() {
    final entries = _patternActivity.entries
        .where((entry) => entry.value.totalDraws > 0)
        .toList();
    entries.sort((a, b) {
      final rateCompare = b.value.rate.compareTo(a.value.rate);
      if (rateCompare != 0) return rateCompare;
      return b.value.patternMatches.compareTo(a.value.patternMatches);
    });
    // Return no more than two ranked games. Using a bounded sublist avoids
    // any negative takeCount calculation if this method is later modified.
    final end = entries.length < 2 ? entries.length : 2;
    return entries.sublist(0, end);
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

    if (_accessChecking || !_accessAllowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Latest Results')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(_accessChecking ? Icons.lock_clock_rounded : Icons.lock_rounded,
              size: 52, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(_accessChecking ? 'Checking access…' : 'Premium access required',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(_accessChecking
              ? 'Please wait while we verify your trial or Lifetime Access.'
              : 'Latest Draw Results and Activity Pattern are available during your 5-day trial or with Lifetime Access.',
              textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.45)),
            if (!_accessChecking) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(onPressed: _checkAccess,
                icon: const Icon(Icons.refresh_rounded), label: const Text('Check again')),
            ],
          ]),
        )),
      );
    }

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
                          selectedColor: const Color(0xFFECE9FF),
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
                      color: const Color(0xFFEFEFF7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Results are read from the official PCSO results page and refresh every 2 minutes. PCSO usually posts after the 9 PM draw. Always confirm winning numbers with PCSO. Patterns are shown for reference only; draws are random and patterns do not predict future results.',
                      style: TextStyle(color: Color(0xFF6E6B86), fontSize: 12, height: 1.5),
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
      color: const Color(0xFFF2F0FF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.insights_rounded, color: _accent),
                SizedBox(width: 8),
                Expanded(
                  child: Text('30-Day Pattern Activity',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Compares how often detected patterns appeared per draw across the five jackpot games.',
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
                    color: Colors.white.withOpacity(0.75),
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
                            Text('${top[i].value.drawsWithPatterns} of ${top[i].value.totalDraws} draws had patterns',
                                style: TextStyle(color: muted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Text('${(top[i].value.rate * 100).round()}%',
                          style: const TextStyle(color: _accent, fontSize: 18, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                if (i < top.length - 1) const SizedBox(height: 8),
              ],
              const SizedBox(height: 10),
              Text(
                'Ranked by the percentage of draws containing at least one detected pattern. This is a historical summary, not a prediction of future winning numbers.',
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
      if (report.hasConsecutive) 'Consecutive run of ${report.longestRun}',
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
                        color: const Color(0xFFECE9FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(c,
                          style: const TextStyle(
                              color: _accent, fontSize: 12, fontWeight: FontWeight.w700)),
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
    required this.patternMatches,
  });

  final int totalDraws;
  final int drawsWithPatterns;
  final int patternMatches;

  double get rate => totalDraws == 0 ? 0 : drawsWithPatterns / totalDraws;
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
        color: highlighted ? const Color(0xFF6254DF) : const Color(0xFFE6E5EE),
      ),
      child: Text(
        number,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: highlighted ? Colors.white : const Color(0xFF3B3957),
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
