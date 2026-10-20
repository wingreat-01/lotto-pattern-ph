import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../services/entitlement_service.dart';

import '../models/generation_mode.dart';
import '../models/lotto_combination.dart';
import '../models/lotto_game.dart';
import '../services/lotto_generator_service.dart';
import '../widgets/combination_card.dart';
import 'latest_results_screen.dart';
import 'pattern_guide_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = LottoGeneratorService();
  LottoGame _game = LottoGame.lotto642;
  int _count = 5;
  bool _plusStep = true;
  GenerationMode _mode = GenerationMode.allPatterns;
  List<LottoCombination> _results = const [];
  String? _error;
  int _generationVersion = 0;

  bool _generating = false;

  Future<void> _generate() async {
    if (_generating) return;
    setState(() { _generating = true; _error = null; });
    try {
      // Generate first so a local generator error does not consume credits.
      final results = _service.generate(
        game: _game,
        count: _count,
        includePlusStep: _plusStep,
        mode: _mode,
      );
      final entitlement = await EntitlementService.instance.consumeCredits(
        count: results.length,
        requestId: const Uuid().v4(),
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _error = null;
        _generationVersion++;
      });
      final remaining = entitlement.lifetimeUnlocked
          ? 'Lifetime access active'
          : '${entitlement.creditsRemaining} credits remaining';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(remaining), duration: const Duration(seconds: 2)),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final message = switch (e.message) {
        'trial_already_used' => 'Your free trial has already been used. Unlock Lifetime Access to continue.',
        'trial_expired' => 'Your 5-day trial has expired. Unlock Lifetime Access to continue.',
        'insufficient_credits' => 'You have run out of free generation credits. Unlock Lifetime Access for unlimited generation.',
        'google_sign_in_required' => 'Please sign in with Google to use pattern generation.',
        _ => 'Could not verify your access. Check your internet connection and try again.',
      };
      setState(() { _error = message; });
    } on StateError catch (e) {
      if (mounted) setState(() { _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not verify your access. Check your internet connection and try again.'; });
    } finally {
      if (mounted) setState(() { _generating = false; });
    }
  }

  void _openGuide() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PatternGuideScreen()),
      );

  Future<void> _openResults() async {
    try {
      final allowed = await EntitlementService.instance.canOpenPremiumFeature();
      if (!mounted) return;
      if (!allowed) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Latest Results and Activity Pattern are available during your 5-day trial or with Lifetime Access.'),
        ));
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LatestResultsScreen(initialGame: _game),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not verify access. Please check your connection and try again.'),
      ));
    }
  }

  void _selectGame(LottoGame game) {
    if (game == _game) return;
    setState(() { _game = game; _results = const []; _error = null; });
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ));
  }

  void _copyAll() {
    final text = [_game.displayName, for (final c in _results) combinationText(c)].join('\n');
    _copy(text, 'Copied ${_results.length} combinations');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8175FF), Color(0xFF5C4BD8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 23),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LottoPattern PH', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              Text('Combination generator', style: TextStyle(fontSize: 12, color: Color(0xFF77758B), fontWeight: FontWeight.w500)),
            ],
          ),
        ]),
        actions: [
          IconButton(
            tooltip: 'Latest Results',
            onPressed: _openResults,
            icon: const Icon(Icons.casino_outlined),
          ),
          IconButton(
            tooltip: 'Pattern guide',
            onPressed: _openGuide,
            icon: const Icon(Icons.menu_book_outlined),
          ),
          IconButton(
            tooltip: 'About pattern generation',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: 'LottoPattern PH',
              applicationVersion: '1.0',
              children: const [Text('Creates number combinations using selected number patterns. It does not predict winning numbers or improve the odds of a random draw.')],
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF29254F), Color(0xFF5144A6), Color(0xFF7165E8)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Stack(children: [
                    Positioned(right: -20, top: -25, child: Icon(Icons.auto_awesome, size: 128, color: Colors.white.withValues(alpha: .08))),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(30)),
                        child: const Text('YOUR NUMBERS, YOUR WAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                      ),
                      const SizedBox(height: 17),
                      const Text('Your numbers.\nYour patterns.', style: TextStyle(color: Colors.white, fontSize: 28, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                      const SizedBox(height: 10),
                      Text('Explore number combinations with seven simple pattern types.', style: TextStyle(color: Colors.white.withValues(alpha: .78), height: 1.4, fontSize: 13)),
                      const SizedBox(height: 20),
                      const Wrap(spacing: 8, runSpacing: 8, children: [
                        _PatternPill(label: 'Plus 2', color: Color(0xFF8EC5FF)),
                        _PatternPill(label: 'Twin', color: Color(0xFFFFC36D)),
                        _PatternPill(label: 'Reversed', color: Color(0xFFC5B5FF)),
                        _PatternPill(label: 'Plus 10', color: Color(0xFFFF9B9E)),
                        _PatternPill(label: 'Plus 20', color: Color(0xFFF2A0D2)),
                        _PatternPill(label: 'Plus 30', color: Color(0xFFB9C4CF)),
                        _PatternPill(label: 'Solo', color: Color(0xFF7FE0D4)),
                      ]),
                    ]),
                  ]),
                ),
                const SizedBox(height: 22),
                const _SectionHeading(number: '01', title: 'Choose your game', subtitle: 'Select a lottery format to get started'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      for (var i = 0; i < LottoGame.values.length; i++) ...[
                        _GameTile(
                          game: LottoGame.values[i],
                          selected: LottoGame.values[i] == _game,
                          onTap: () => _selectGame(LottoGame.values[i]),
                        ),
                        if (i != LottoGame.values.length - 1)
                          const Divider(height: 8, indent: 52, color: Color(0xFFF0EFF6)),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionHeading(number: '02', title: 'Set your combinations', subtitle: 'Choose how many sets to generate'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Expanded(child: Text('Number of sets', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(color: const Color(0xFFF0EEFF), borderRadius: BorderRadius.circular(12)),
                          child: Text('$_count', style: const TextStyle(color: Color(0xFF5C4BD8), fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                      Slider(
                        value: _count.toDouble(), min: 1, max: 10, divisions: 9,
                        label: '$_count sets',
                        onChanged: (v) => setState(() => _count = v.round()),
                      ),
                      const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('1 set', style: TextStyle(fontSize: 11, color: Color(0xFF858399))),
                        Text('10 sets', style: TextStyle(fontSize: 11, color: Color(0xFF858399))),
                      ]),
                      const Divider(height: 20, color: Color(0xFFF0EFF6)),
                      const Text('Pattern mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<GenerationMode>(
                          showSelectedIcon: false,
                          segments: [
                            for (final m in GenerationMode.values)
                              ButtonSegment(value: m, label: Text(m.label)),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (v) => setState(() { _mode = v.first; _results = const []; _error = null; }),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_mode.description, style: const TextStyle(fontSize: 11, color: Color(0xFF858399))),
                      if (_mode == GenerationMode.allPatterns) ...[
                        const SizedBox(height: 6),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _plusStep,
                          onChanged: (v) => setState(() { _plusStep = v; _results = const []; _error = null; }),
                          title: const Text('Plus 10 / 20 / 30 pattern', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          subtitle: const Text('Adds ONE random pair per set: Plus 10, 20 or 30 (e.g. 09 → 39). Off = random solo number.', style: TextStyle(fontSize: 11, height: 1.4)),
                        ),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 58,
                  child: FilledButton.icon(
                    onPressed: _generate,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 21),
                    label: const Text('Generate combinations', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6254DF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(14)),
                    child: Text(_error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                  ),
                ],
                const SizedBox(height: 28),
                if (_results.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFEAE9F3)),
                    ),
                    child: Column(children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(color: const Color(0xFFF0EEFF), borderRadius: BorderRadius.circular(22)),
                        child: const Icon(Icons.confirmation_number_outlined, color: Color(0xFF6254DF), size: 32),
                      ),
                      const SizedBox(height: 14),
                      const Text('Your combinations appear here', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('Choose a game and tap Generate to create your number sets.', textAlign: TextAlign.center, style: TextStyle(color: muted, height: 1.45, fontSize: 13)),
                    ]),
                  ),
                ] else ...[
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Generated sets', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.4)),
                      const SizedBox(height: 3),
                      Text('${_results.length} sets · ${_game.displayName}', style: TextStyle(color: muted, fontSize: 12)),
                    ])),
                    OutlinedButton.icon(
                      onPressed: _copyAll,
                      icon: const Icon(Icons.copy_all_rounded, size: 17),
                      label: const Text('Copy all'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5C4BD8),
                        side: const BorderSide(color: Color(0xFFDCD8FF)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  const PatternLegend(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openGuide,
                      icon: const Icon(Icons.help_outline_rounded, size: 17),
                      label: const Text('What do these patterns mean?'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF5C4BD8), padding: EdgeInsets.zero),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < _results.length; i++) ...[
                    CombinationCard(
                      key: ValueKey('$_generationVersion-$i'),
                      index: i + 1,
                      combination: _results[i],
                      onCopy: () => _copy(combinationText(_results[i]), 'Copied ${combinationText(_results[i])}'),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFEFEFF7), borderRadius: BorderRadius.circular(16)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline_rounded, size: 19, color: Color(0xFF6E6B86)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('For entertainment only. Lottery draws are random, and these patterns do not predict results or improve your odds. Please play responsibly.', style: TextStyle(color: muted, fontSize: 11, height: 1.5))),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PatternPill extends StatelessWidget {
  const _PatternPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withValues(alpha: .12))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.number, required this.title, required this.subtitle});
  final String number, title, subtitle;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      width: 34, height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: const Color(0xFFEAE7FF), borderRadius: BorderRadius.circular(12)),
      child: Text(number, style: const TextStyle(color: Color(0xFF6254DF), fontSize: 11, fontWeight: FontWeight.w900)),
    ),
    const SizedBox(width: 11),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -.2)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF858399))),
    ])),
  ]);
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game, required this.selected, required this.onTap});
  final LottoGame game;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFECE9FF) : const Color(0xFFF4F3F9),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.casino_outlined, color: selected ? const Color(0xFF6254DF) : const Color(0xFF89869E), size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(game.displayName, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: const Color(0xFF222139))),
          const SizedBox(height: 3),
          Text('Pick 6 numbers · 1–${game.maxNumber}', style: const TextStyle(fontSize: 11, color: Color(0xFF89869E))),
        ])),
        if (selected)
          const Icon(Icons.check_circle_rounded, color: Color(0xFF6254DF), size: 22)
        else
          const Icon(Icons.circle_outlined, color: Color(0xFFD4D2E1), size: 22),
      ]),
    ),
  );
}
