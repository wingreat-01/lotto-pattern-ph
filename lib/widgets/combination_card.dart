import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../models/lotto_combination.dart';

enum PatternRole {
  plusTwo('Plus 2', Color(0xFF3478F6)),
  twin('Twin', Color(0xFFE69A24)),
  reverse('Reversed', Color(0xFF8767E8)),
  plus10('Plus 10', Color(0xFFE5484D)),
  plus20('Plus 20', Color(0xFFD6409F)),
  plus30('Plus 30', Color(0xFF5B6B7B)),
  solo('Solo', Color(0xFF149B91));

  const PatternRole(this.label, this.color);
  final String label;
  final Color color;
}

String twoDigits(int n) => n.toString().padLeft(2, '0');

PatternRole roleOf(LottoCombination c, int n) {
  for (final plus2 in c.plusTwoPairs) {
    if (n == plus2.first || n == plus2.second) return PatternRole.plusTwo;
  }
  if (c.twinNumbers.contains(n)) return PatternRole.twin;
  final reverse = c.reversePair;
  if (reverse != null && (n == reverse.first || n == reverse.second)) return PatternRole.reverse;
  final step = c.plusStepPair;
  if (step != null && (n == step.first || n == step.second)) {
    return switch (c.plusStep) {
      10 => PatternRole.plus10,
      20 => PatternRole.plus20,
      _ => PatternRole.plus30,
    };
  }
  return PatternRole.solo;
}

String combinationText(LottoCombination c) => c.numbers.map(twoDigits).join(' ');

class PatternLegend extends StatelessWidget {
  const PatternLegend({super.key});
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8, runSpacing: 8,
    children: [
      for (final role in PatternRole.values)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: role.color.withValues(alpha: .09), borderRadius: BorderRadius.circular(30)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: role.color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(role.label, style: TextStyle(color: role.color, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
    ],
  );
}

class CombinationCard extends StatelessWidget {
  const CombinationCard({super.key, required this.index, required this.combination, required this.onCopy});
  final int index;
  final LottoCombination combination;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = combination;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 280 + (index.clamp(1, 8).toInt() * 45)),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - progress)),
          child: child,
        ),
      ),
      child: Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: context.lc.tint, borderRadius: BorderRadius.circular(10)),
              child: Text('SET ${index.toString().padLeft(2, '0')}', style: TextStyle(color: context.lc.accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .7)),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Copy numbers',
              onPressed: onCopy,
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              style: IconButton.styleFrom(backgroundColor: context.lc.neutralFill, foregroundColor: context.lc.muted),
            ),
          ]),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            const gap = 7.0;
            final size = ((constraints.maxWidth - gap * 5) / 6).clamp(32.0, 48.0);
            return Row(
              children: [
                for (var i = 0; i < c.numbers.length; i++) ...[
                  if (i > 0) const SizedBox(width: gap),
                  Expanded(child: Center(child: _NumberBall(number: c.numbers[i], role: roleOf(c, c.numbers[i]), size: size))),
                ],
              ],
            );
          }),
          const SizedBox(height: 16),
          Container(height: 1, color: context.lc.hairline),
          const SizedBox(height: 12),
          Text('PATTERN BREAKDOWN', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final pair in c.plusTwoPairs)
              _DetailChip(label: 'Plus 2', value: '${twoDigits(pair.first)} + ${twoDigits(pair.second)}', color: PatternRole.plusTwo.color),
            for (final twin in c.twinNumbers)
              _DetailChip(label: 'Twin', value: twoDigits(twin), color: PatternRole.twin.color),
            if (c.reversePair != null)
              _DetailChip(label: 'Reversed', value: '${twoDigits(c.reversePair!.first)} ↔ ${twoDigits(c.reversePair!.second)}', color: PatternRole.reverse.color),
            if (c.plusStepPair != null)
              _DetailChip(
                label: 'Plus ${c.plusStep}',
                value: '${twoDigits(c.plusStepPair!.first)} + ${c.plusStep} = ${twoDigits(c.plusStepPair!.second)}',
                color: roleOf(c, c.plusStepPair!.second).color,
              ),
            if (c.soloNumber != null)
              _DetailChip(label: 'Solo', value: twoDigits(c.soloNumber!), color: PatternRole.solo.color),
          ]),
        ]),
      ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(11)),
    child: RichText(text: TextSpan(style: const TextStyle(fontSize: 11), children: [
      TextSpan(text: '$label  ', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      TextSpan(text: value, style: TextStyle(color: context.lc.strongText, fontWeight: FontWeight.w800)),
    ])),
  );
}

class _NumberBall extends StatelessWidget {
  const _NumberBall({required this.number, required this.role, required this.size});
  final int number;
  final PatternRole role;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${twoDigits(number)}, ${role.label}',
    child: TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.82, end: 1.0),
      duration: const Duration(milliseconds: 360),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [role.color.withValues(alpha: .88), role.color], begin: Alignment.topLeft, end: Alignment.bottomRight),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: role.color.withValues(alpha: .18), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Text(twoDigits(number), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: size * .34, letterSpacing: -.3)),
      ),
    ),
  );
}
