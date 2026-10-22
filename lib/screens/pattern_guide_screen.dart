import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../widgets/combination_card.dart';

/// Explains every pattern with its meaning and sample numbers.
class PatternGuideScreen extends StatelessWidget {
  const PatternGuideScreen({super.key});

  static const _patterns = <_PatternInfo>[
    _PatternInfo(
      role: PatternRole.plusTwo,
      meaning: 'Two numbers that are exactly 2 apart.',
      samples: [
        _Sample([14, 16], '14 + 2 = 16'),
        _Sample([31, 33], '31 + 2 = 33'),
      ],
    ),
    _PatternInfo(
      role: PatternRole.twin,
      meaning: 'One number made of the same two digits.',
      samples: [
        _Sample([11], '11'),
        _Sample([33], '33'),
      ],
      note: 'Only twins inside the game\'s range count. For example, 44 is not available in Lotto 6/42.',
    ),
    _PatternInfo(
      role: PatternRole.reverse,
      meaning: 'Two numbers that are each other\'s digits flipped.',
      samples: [
        _Sample([4, 40], '04 ↔ 40'),
        _Sample([14, 41], '14 ↔ 41'),
      ],
      note: 'Single digits count with a leading zero (4 = 04). Both numbers must fit the game, so 25 ↔ 52 cannot be used in Lotto 6/42.',
    ),
    _PatternInfo(
      role: PatternRole.plus10,
      meaning: 'Two numbers that are exactly 10 apart.',
      samples: [
        _Sample([19, 29], '19 + 10 = 29'),
        _Sample([7, 17], '07 + 10 = 17'),
      ],
      note: 'Plus 10, Plus 20 and Plus 30 are separate patterns. A set uses only one of them, picked at random.',
    ),
    _PatternInfo(
      role: PatternRole.plus20,
      meaning: 'Two numbers that are exactly 20 apart.',
      samples: [
        _Sample([5, 25], '05 + 20 = 25'),
        _Sample([12, 32], '12 + 20 = 32'),
      ],
    ),
    _PatternInfo(
      role: PatternRole.plus30,
      meaning: 'Two numbers that are exactly 30 apart.',
      samples: [
        _Sample([9, 39], '09 + 30 = 39'),
        _Sample([8, 38], '08 + 30 = 38'),
      ],
    ),
    _PatternInfo(
      role: PatternRole.solo,
      meaning: 'A free number with no pattern. It fills a spare slot.',
      samples: [
        _Sample([27], '27'),
        _Sample([36], '36'),
      ],
      note: 'Solo appears when the Plus 10/20/30 switch is off, or in some Mix sets.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Pattern guide', style: TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
              children: [
                Text(
                  'Each number ball in your results is colored by the pattern it belongs to. Here is what every color means.',
                  style: TextStyle(color: muted, height: 1.45, fontSize: 13),
                ),
                const SizedBox(height: 16),
                for (final info in _patterns) ...[
                  _PatternTile(info: info),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 6),
                const _SectionTitle('Putting it together'),
                const SizedBox(height: 10),
                const _ExampleSetCard(),
                const SizedBox(height: 12),
                const _ModesCard(),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: context.lc.neutralFill, borderRadius: BorderRadius.circular(16)),
                  child: Text(
                    'Samples use Lotto 6/42 numbers. These patterns do not predict results or improve your odds of winning. Every draw is random.',
                    style: TextStyle(color: muted, fontSize: 11, height: 1.5),
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

class _Sample {
  const _Sample(this.numbers, this.caption);
  final List<int> numbers;
  final String caption;
}

class _PatternInfo {
  const _PatternInfo({required this.role, required this.meaning, required this.samples, this.note});
  final PatternRole role;
  final String meaning;
  final List<_Sample> samples;
  final String? note;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -.3));
}

class _PatternTile extends StatelessWidget {
  const _PatternTile({required this.info});
  final _PatternInfo info;

  @override
  Widget build(BuildContext context) {
    final role = info.role;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: role.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(role.label, style: TextStyle(color: role.color, fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          Text(info.meaning, style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          Wrap(spacing: 22, runSpacing: 12, children: [
            for (final sample in info.samples)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final n in sample.numbers) ...[
                    GuideBall(number: n, color: role.color),
                    const SizedBox(width: 6),
                  ],
                ]),
                const SizedBox(height: 5),
                Text(sample.caption, style: TextStyle(fontSize: 11, color: context.lc.muted, fontWeight: FontWeight.w600)),
              ]),
          ]),
          if (info.note != null) ...[
            const SizedBox(height: 12),
            Text(info.note!, style: TextStyle(fontSize: 11, height: 1.45, color: context.lc.muted)),
          ],
        ]),
      ),
    );
  }
}

class _ExampleSetCard extends StatelessWidget {
  const _ExampleSetCard();

  // 04 and 40 reversed, 14 and 16 plus 2, 22 twin, 24 = 14 + 10.
  static const _numbers = <int, PatternRole>{
    4: PatternRole.reverse,
    14: PatternRole.plusTwo,
    16: PatternRole.plusTwo,
    22: PatternRole.twin,
    24: PatternRole.plus10,
    40: PatternRole.reverse,
  };

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Example set', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final e in _numbers.entries) GuideBall(number: e.key, color: e.value.color),
            ]),
            const SizedBox(height: 12),
            const Text(
              'Plus 2: 14 + 16  ·  Twin: 22  ·  Reversed: 04 ↔ 40  ·  Plus 10: 14 + 10 = 24',
              style: TextStyle(fontSize: 12, height: 1.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'The Plus 10 pair reuses 14 from the Plus 2 pair, so all the patterns fit in six numbers. Only the new number (24) is colored as Plus 10.',
              style: TextStyle(fontSize: 11, height: 1.45, color: context.lc.muted),
            ),
          ]),
        ),
      );
}

class _ModesCard extends StatelessWidget {
  const _ModesCard();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Modes and rules', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            SizedBox(height: 10),
            _Bullet(title: 'All patterns', text: 'Every set has Plus 2, Twin and Reversed, plus one random Plus 10, 20 or 30 pair.'),
            _Bullet(title: 'Mix', text: 'Each set uses a different mix of patterns. Patterns never share numbers, and a set has at most one Plus 10/20/30 pair.'),
            _Bullet(title: 'No long runs', text: 'Sets never have more than 2 numbers in a row. For example, 11, 12, 13 will not appear.'),
          ]),
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(
          text: TextSpan(style: TextStyle(fontSize: 12, height: 1.5, color: context.lc.strongText), children: [
            TextSpan(text: '$title  ', style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: text),
          ]),
        ),
      );
}

/// A small colored number ball used in the guide.
class GuideBall extends StatelessWidget {
  const GuideBall({super.key, required this.number, required this.color, this.size = 38});
  final int number;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: .88), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withValues(alpha: .18), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Text(twoDigits(number), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * .34, letterSpacing: -.3)),
      );
}
