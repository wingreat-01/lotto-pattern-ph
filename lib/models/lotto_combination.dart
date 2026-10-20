import 'lotto_game.dart';

typedef LottoPair = ({int first, int second});

class LottoCombination {
  LottoCombination({
    required this.game,
    required List<int> numbers,
    this.plusTwoPair,
    this.extraPlusTwoPair,
    this.twinNumber,
    this.extraTwinNumber,
    this.reversePair,
    this.soloNumber,
    this.plusStepPair,
  }) : numbers = List.unmodifiable(numbers) {
    if (this.numbers.length != game.numbersToDraw) {
      throw ArgumentError('Combination must contain ${game.numbersToDraw} numbers.');
    }
    if (this.numbers.toSet().length != this.numbers.length) {
      throw ArgumentError('Combination numbers must be unique.');
    }
    if (this.numbers.any((n) => !game.isValidNumber(n))) {
      throw ArgumentError('Combination contains a number outside the game range.');
    }
    for (var i = 1; i < this.numbers.length; i++) {
      if (this.numbers[i - 1] > this.numbers[i]) {
        throw ArgumentError('Combination numbers must be sorted ascending.');
      }
    }

    final covered = <int>{};
    final plus2 = plusTwoPair;
    if (plus2 != null) {
      if (plus2.second - plus2.first != 2 ||
          !this.numbers.contains(plus2.first) ||
          !this.numbers.contains(plus2.second)) {
        throw ArgumentError('Plus 2 pair must be included and differ by 2.');
      }
      covered..add(plus2.first)..add(plus2.second);
    }
    final plus2b = extraPlusTwoPair;
    if (plus2b != null) {
      if (plus2 == null ||
          plus2b.second - plus2b.first != 2 ||
          !this.numbers.contains(plus2b.first) ||
          !this.numbers.contains(plus2b.second)) {
        throw ArgumentError('Second Plus 2 pair must be included and differ by 2.');
      }
      covered..add(plus2b.first)..add(plus2b.second);
    }
    final twin2 = extraTwinNumber;
    if (twin2 != null) {
      if (twinNumber == null || !_isTwin(twin2) || !this.numbers.contains(twin2)) {
        throw ArgumentError('A valid second twin number must be included.');
      }
      covered.add(twin2);
    }
    final twin = twinNumber;
    if (twin != null) {
      if (!_isTwin(twin) || !this.numbers.contains(twin)) {
        throw ArgumentError('A valid twin number must be included.');
      }
      covered.add(twin);
    }
    final reverse = reversePair;
    if (reverse != null) {
      if (!_areReversed(reverse.first, reverse.second) ||
          !this.numbers.contains(reverse.first) ||
          !this.numbers.contains(reverse.second)) {
        throw ArgumentError('Both reversed-pair numbers must be included.');
      }
      covered..add(reverse.first)..add(reverse.second);
    }
    final solo = soloNumber;
    if (solo != null) {
      if (!this.numbers.contains(solo)) {
        throw ArgumentError('Solo number must be included.');
      }
      covered.add(solo);
    }
    final step = plusStepPair;
    if (step != null) {
      if (!plusSteps.contains(step.second - step.first) ||
          !this.numbers.contains(step.first) ||
          !this.numbers.contains(step.second)) {
        throw ArgumentError('Plus-step pair must be included and differ by 10, 20 or 30.');
      }
      covered..add(step.first)..add(step.second);
    }
    if (!this.numbers.every(covered.contains)) {
      throw ArgumentError('Every number must belong to a pattern.');
    }
  }

  /// Allowed differences for the plus-step patterns: Plus 10, Plus 20, Plus 30.
  static const plusSteps = [10, 20, 30];

  final LottoGame game;
  final List<int> numbers;

  /// Pattern parts. Each is null when the set does not use that pattern
  /// (mix mode can leave patterns out).
  final LottoPair? plusTwoPair;

  /// A second Plus 2 pair, when the set has two (mix mode only).
  final LottoPair? extraPlusTwoPair;
  final int? twinNumber;

  /// A second twin number, when the set has two (mix mode only).
  final int? extraTwinNumber;

  /// Every Plus 2 pair in the set (0, 1 or 2).
  List<LottoPair> get plusTwoPairs =>
      [if (plusTwoPair != null) plusTwoPair!, if (extraPlusTwoPair != null) extraPlusTwoPair!];

  /// Every twin number in the set (0, 1 or 2).
  List<int> get twinNumbers =>
      [if (twinNumber != null) twinNumber!, if (extraTwinNumber != null) extraTwinNumber!];
  final LottoPair? reversePair;

  /// Number picked freely, or null if the set has none.
  final int? soloNumber;

  /// Pair (n, n + step) where step is exactly one of 10, 20 or 30 (the separate
  /// Plus 10, Plus 20 and Plus 30 patterns; a set never has more than one).
  /// In "all patterns" mode it shares one number with another pattern.
  final LottoPair? plusStepPair;

  /// 10, 20 or 30 for the plus-step pair, or null if the set has none.
  int? get plusStep =>
      plusStepPair == null ? null : plusStepPair!.second - plusStepPair!.first;

  static bool _isTwin(int n) {
    final text = n.toString().padLeft(2, '0');
    return text.length == 2 && text[0] == text[1];
  }

  static bool _areReversed(int a, int b) {
    final left = a.toString().padLeft(2, '0');
    final right = b.toString().padLeft(2, '0');
    return left.split('').reversed.join() == right && a < b;
  }
}
