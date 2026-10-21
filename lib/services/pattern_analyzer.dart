import '../models/lotto_combination.dart';

/// Which of the app's patterns appear in a set of drawn numbers.
class PatternReport {
  const PatternReport({
    required this.plusTwo,
    required this.twins,
    required this.reversed,
    required this.plusSteps,
    required this.longestRun,
    required this.involved,
    this.solo,
  });

  final List<LottoPair> plusTwo;
  final List<int> twins;
  final List<LottoPair> reversed;

  /// Key is 10, 20 or 30; value is every (n, n + step) pair found.
  final Map<int, List<LottoPair>> plusSteps;

  /// Longest run of consecutive numbers (1 means none are adjacent).
  final int longestRun;

  /// Every number that belongs to at least one detected pattern.
  final Set<int> involved;

  /// The one leftover number when the other five already form patterns
  /// (e.g. 35 in 17-19-24-35-52-54). Null when it does not apply.
  final int? solo;

  /// Informational only. Consecutive numbers are not one of the app's patterns,
  /// so this is not shown as a chip and does not count toward `hasAny`.
  bool get hasConsecutive => longestRun >= 2;

  bool get hasAny =>
      plusTwo.isNotEmpty ||
      twins.isNotEmpty ||
      reversed.isNotEmpty ||
      plusSteps.values.any((p) => p.isNotEmpty);
}

/// Uses the same definitions as the generator (see README):
/// plus 2, twin, reversed pair and plus 10/20/30 (consecutive runs are only
/// limited by the generator, they are not a pattern).
class PatternAnalyzer {
  const PatternAnalyzer();

  PatternReport analyze(List<int> drawn) {
    final numbers = [...drawn]..sort();
    final set = numbers.toSet();
    final involved = <int>{};

    final plusTwo = <LottoPair>[];
    for (final n in numbers) {
      if (set.contains(n + 2)) {
        plusTwo.add((first: n, second: n + 2));
        involved..add(n)..add(n + 2);
      }
    }

    final twins = <int>[];
    for (final n in numbers) {
      if (_isTwin(n)) {
        twins.add(n);
        involved.add(n);
      }
    }

    final reversed = <LottoPair>[];
    for (final n in numbers) {
      final r = int.parse(n.toString().padLeft(2, '0').split('').reversed.join());
      if (r > n && set.contains(r)) {
        reversed.add((first: n, second: r));
        involved..add(n)..add(r);
      }
    }

    final plusSteps = <int, List<LottoPair>>{};
    for (final step in LottoCombination.plusSteps) {
      final pairs = <LottoPair>[];
      for (final n in numbers) {
        if (set.contains(n + step)) {
          pairs.add((first: n, second: n + step));
          involved..add(n)..add(n + step);
        }
      }
      plusSteps[step] = pairs;
    }

    var longest = numbers.isEmpty ? 0 : 1;
    var run = 1;
    for (var i = 1; i < numbers.length; i++) {
      run = numbers[i] == numbers[i - 1] + 1 ? run + 1 : 1;
      if (run > longest) longest = run;
    }
    // Consecutive runs are NOT a pattern, so they never add to `involved`.

    // If five of the six numbers already belong to a pattern, the remaining
    // number is the "solo" number.
    int? solo;
    if (numbers.length > 1 && involved.length == numbers.length - 1) {
      final rest = numbers.where((n) => !involved.contains(n)).toList();
      if (rest.length == 1) solo = rest.first;
    }

    return PatternReport(
      plusTwo: plusTwo,
      twins: twins,
      reversed: reversed,
      plusSteps: plusSteps,
      longestRun: longest,
      involved: involved,
      solo: solo,
    );
  }

  static bool _isTwin(int n) => n >= 11 && n % 11 == 0 && n < 100;
}
