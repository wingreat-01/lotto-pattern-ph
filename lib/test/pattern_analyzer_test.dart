import 'package:flutter_test/flutter_test.dart';

import 'package:lotto_pattern_app/services/pattern_analyzer.dart';

void main() {
  const analyzer = PatternAnalyzer();

  test('detects plus 2, twin, reversed, plus steps and runs', () {
    final r = analyzer.analyze([4, 6, 22, 40, 41, 42]);
    expect(r.plusTwo.map((p) => p.first), containsAll([4, 40]));
    expect(r.twins, [22]);
    expect(r.reversed.map((p) => (p.first, p.second)), contains((4, 40)));
    expect(r.plusSteps[20]!.map((p) => p.first), contains(22));
    expect(r.longestRun, 3);
    expect(r.hasAny, isTrue);
  });

  test('reports no patterns for scattered numbers', () {
    final r = analyzer.analyze([1, 8, 16, 27, 35, 44]);
    expect(r.twins, isEmpty);
    expect(r.hasConsecutive, isFalse);
  });

  test('tags the sixth number as solo when the other five have patterns', () {
    final r = analyzer.analyze([17, 19, 24, 35, 52, 54]);
    expect(r.solo, 35);
  });

  test('no solo when two numbers are unpatterned or all six are patterned', () {
    expect(analyzer.analyze([17, 19, 24, 54, 35, 41]).solo, isNull);
    expect(analyzer.analyze([17, 19, 52, 54, 24, 14]).solo, isNull);
  });

  test('adjacent numbers are not a pattern and do not make a solo', () {
    final r = analyzer.analyze([1, 11, 19, 20, 23, 39]);
    expect(r.twins, [11]);
    expect(r.involved, {1, 11, 19, 39});
    expect(r.solo, isNull); // 20 and 23 are both unpatterned
  });
}
