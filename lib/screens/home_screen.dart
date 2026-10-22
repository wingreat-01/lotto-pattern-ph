import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import '../services/monetization_service.dart';

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
  int _selectedNavIndex = 0;

  Future<void> _generate() async {
    if (_generating) return;
    setState(() { _generating = true; _error = null; });
    try {
      // Generate locally first so invalid settings never consume an ad reward.
      final results = _service.generate(
        game: _game,
        count: _count,
        includePlusStep: _plusStep,
        mode: _mode,
      );
      final monetization = MonetizationService.instance;
      if (!monetization.isPremium) {
        final earned = await monetization.showRewardedAd();
        if (!mounted) return;
        if (!earned) {
          setState(() {
            _error = 'A rewarded video is not ready or was not completed. Please try again, or unlock Lifetime Premium to generate without ads.';
          });
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        _results = results;
        _error = null;
        _generationVersion++;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(monetization.isPremium ? 'Lifetime Premium active — no ads' : 'Reward earned. Here are your combinations!'),
        duration: const Duration(seconds: 2),
      ));
    } on StateError catch (e) {
      if (mounted) setState(() { _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not generate combinations. Please try again.'; });
    } finally {
      if (mounted) setState(() { _generating = false; });
    }
  }

  Future<void> _showPremiumDialog() async {
    final service = MonetizationService.instance;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AnimatedBuilder(
        animation: service,
        builder: (context, _) => AlertDialog(
          title: const Text('Unlock Lifetime Premium'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Generate combinations without watching ads. One payment, no subscription.'),
              const SizedBox(height: 12),
              Text(service.lifetimePrice, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Includes unlimited pattern generation and an ad-free experience.'),
              if (service.purchaseError != null) ...[
                const SizedBox(height: 12),
                Text(service.purchaseError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: service.isBusy ? null : () => service.restorePurchases(), child: const Text('Restore')),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Not now')),
            FilledButton(
              onPressed: service.isBusy || service.isPremium ? null : () async {
                await service.buyLifetime();
                if (!dialogContext.mounted) return;
                if (service.isPremium) Navigator.of(dialogContext).pop();
              },
              child: Text(service.isBusy ? 'Please wait…' : service.isPremium ? 'Premium active' : 'Unlock once'),
            ),
          ],
        ),
      ),
    );
    if (mounted && service.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lifetime Premium is active.')));
    }
  }

  void _openGuide() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PatternGuideScreen()),
      );

  Future<void> _openResults() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LatestResultsScreen(initialGame: _game),
    ));
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
    final lc = context.lc;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Open navigation menu',
            icon: const Icon(Icons.menu_rounded, size: 27),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        titleSpacing: 4,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/lotto_pattern_ph_logo.png',
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A43C2), Color(0xFF092477)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.casino_rounded, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Lotto Pattern PH', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -.45)),
                  Text('Number pattern generator',
                    style: TextStyle(fontSize: 11, color: lc.muted, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: theme.brightness == Brightness.dark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () => ThemeController.instance.toggle(context),
            icon: Icon(theme.brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          ),
          AnimatedBuilder(
            animation: MonetizationService.instance,
            builder: (context, _) => IconButton(
              tooltip: MonetizationService.instance.isPremium ? 'Lifetime Premium active' : 'Unlock Lifetime Premium',
              onPressed: MonetizationService.instance.isPremium ? null : _showPremiumDialog,
              icon: Icon(
                MonetizationService.instance.isPremium ? Icons.workspace_premium_rounded : Icons.workspace_premium_outlined,
                color: const Color(0xFFE0A800),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: lc.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF082B8A), Color(0xFF0759D8)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset('assets/images/lotto_pattern_ph_logo.png',
                        width: 58, height: 58, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lotto Pattern PH', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('Explore. Generate. Review.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _drawerItem(context, icon: Icons.home_rounded, label: 'Home', onTap: () => Navigator.pop(context)),
              _drawerItem(context, icon: Icons.auto_graph_rounded, label: 'Pattern Guide', onTap: () { Navigator.pop(context); _openGuide(); }),
              _drawerItem(context, icon: Icons.casino_rounded, label: 'Latest Draw Results', onTap: () { Navigator.pop(context); _openResults(); }),
              _drawerItem(context, icon: Icons.workspace_premium_rounded, label: 'Lifetime Premium', onTap: () { Navigator.pop(context); _showPremiumDialog(); }),
              const Divider(indent: 18, endIndent: 18, height: 24),
              _drawerItem(context, icon: Icons.info_outline_rounded, label: 'About Lotto Pattern PH', onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'Lotto Pattern PH',
                  applicationVersion: '1.0',
                  children: const [Text('Creates number combinations using selected number patterns. It does not predict winning numbers or improve the odds of a random draw.')],
                );
              }),
              SwitchListTile(
                secondary: Icon(Icons.dark_mode_rounded, color: lc.drawerIcon),
                title: const Text('Dark mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                value: theme.brightness == Brightness.dark,
                onChanged: (v) => ThemeController.instance.setMode(v ? ThemeMode.dark : ThemeMode.light),
                contentPadding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                child: Text('For entertainment only. Lottery draws are random.',
                  style: TextStyle(color: lc.muted, fontSize: 11, height: 1.4)),
              ),
            ],
          ),
        ),
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
                      colors: [Color(0xFF06277F), Color(0xFF064BC0), Color(0xFF0878E8)],
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
                        child: const Text('EXPLORE PATTERNS · GENERATE NUMBERS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                      ),
                      const SizedBox(height: 17),
                      const Text('Your numbers.\nYour patterns.', style: TextStyle(color: Colors.white, fontSize: 28, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                      const SizedBox(height: 10),
                      Text('Explore number combinations for supported Philippine lotto games.', style: TextStyle(color: Colors.white.withValues(alpha: .78), height: 1.4, fontSize: 13)),
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
                          Divider(height: 8, indent: 52, color: lc.hairline),
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
                          decoration: BoxDecoration(color: lc.tint, borderRadius: BorderRadius.circular(12)),
                          child: Text('$_count', style: TextStyle(color: lc.accent, fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                      ]),
                      Slider(
                        value: _count.toDouble(), min: 1, max: 10, divisions: 9,
                        label: '$_count sets',
                        onChanged: (v) => setState(() => _count = v.round()),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('1 set', style: TextStyle(fontSize: 11, color: lc.muted)),
                        Text('10 sets', style: TextStyle(fontSize: 11, color: lc.muted)),
                      ]),
                      Divider(height: 20, color: lc.hairline),
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
                      Text(_mode.description, style: TextStyle(fontSize: 11, color: lc.muted)),
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
                    onPressed: _generating ? null : _generate,
                    icon: Icon(_generating ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded, size: 21),
                    label: Text(_generating ? 'Preparing your combinations…' : MonetizationService.instance.isPremium ? 'Generate combinations — No ads' : 'Watch ad to generate', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6254DF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: MonetizationService.instance,
                  builder: (context, _) => OutlinedButton.icon(
                    onPressed: MonetizationService.instance.isPremium ? null : _showPremiumDialog,
                    icon: const Icon(Icons.workspace_premium_rounded),
                    label: Text(MonetizationService.instance.isPremium ? 'Lifetime Premium active' : 'Remove ads — Lifetime Premium'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: lc.accent,
                      side: BorderSide(color: lc.outlineAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      color: lc.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: lc.border),
                    ),
                    child: Column(children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(color: lc.tint, borderRadius: BorderRadius.circular(22)),
                        child: Icon(Icons.confirmation_number_outlined, color: lc.accent, size: 32),
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
                        foregroundColor: lc.accent,
                        side: BorderSide(color: lc.outlineAccent),
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
                      style: TextButton.styleFrom(foregroundColor: lc.accent, padding: EdgeInsets.zero),
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
                  decoration: BoxDecoration(color: lc.neutralFill, borderRadius: BorderRadius.circular(16)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline_rounded, size: 19, color: lc.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text('For entertainment only. Lottery draws are random, and these patterns do not predict results or improve your odds. Please play responsibly.', style: TextStyle(color: muted, fontSize: 11, height: 1.5))),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        height: 68,
        backgroundColor: lc.surface,
        indicatorColor: lc.navIndicator,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) async {
          setState(() => _selectedNavIndex = index);
          switch (index) {
            case 0:
              break;
            case 1:
              _openGuide();
              if (mounted) setState(() => _selectedNavIndex = 0);
              break;
            case 2:
              await _openResults();
              if (mounted) setState(() => _selectedNavIndex = 0);
              break;
            case 3:
              await _showPremiumDialog();
              if (mounted) setState(() => _selectedNavIndex = 0);
              break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.auto_graph_outlined), selectedIcon: Icon(Icons.auto_graph_rounded), label: 'Patterns'),
          NavigationDestination(icon: Icon(Icons.casino_outlined), selectedIcon: Icon(Icons.casino_rounded), label: 'Results'),
          NavigationDestination(icon: Icon(Icons.workspace_premium_outlined), selectedIcon: Icon(Icons.workspace_premium_rounded), label: 'Premium'),
        ],
      ),
    );
  }
}

Widget _drawerItem(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
  return ListTile(
    leading: Icon(icon, color: context.lc.drawerIcon),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
    trailing: Icon(Icons.chevron_right_rounded, color: context.lc.iconDim),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 22),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
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
      decoration: BoxDecoration(color: context.lc.tint, borderRadius: BorderRadius.circular(12)),
      child: Text(number, style: TextStyle(color: context.lc.accent, fontSize: 11, fontWeight: FontWeight.w900)),
    ),
    const SizedBox(width: 11),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -.2)),
      const SizedBox(height: 3),
      Text(subtitle, style: TextStyle(fontSize: 12, color: context.lc.muted)),
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
            color: selected ? context.lc.tint : context.lc.neutralFill,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.casino_outlined, color: selected ? context.lc.accent : context.lc.muted, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(game.displayName, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: context.lc.strongText)),
          const SizedBox(height: 3),
          Text('Pick 6 numbers · 1–${game.maxNumber}', style: TextStyle(fontSize: 11, color: context.lc.muted)),
        ])),
        if (selected)
          Icon(Icons.check_circle_rounded, color: context.lc.accent, size: 22)
        else
          Icon(Icons.circle_outlined, color: context.lc.iconDim, size: 22),
      ]),
    ),
  );
}
