import 'dart:math';

import '../models/lotto_combination.dart';
import '../models/generation_mode.dart';
import '../models/lotto_game.dart';

class LottoGeneratorService {
  LottoGeneratorService({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Creates combinations containing the patterns in the same six-number set:
  /// plus-2 pair (2 slots), twin (1), reverse pair (2) and one more number.
  ///
  /// With [includePlusStep] (default) that sixth number is the partner of one
  /// plus pair. Plus 10, Plus 20 and Plus 30 are separate patterns and each set
  /// gets exactly ONE of them, chosen at random: the sixth number equals one of
  /// the other five +/- that step (e.g. 9 and 39 for Plus 30). The pair shares
  /// one number with another pattern so it fits into six slots. With
  /// [includePlusStep] false the sixth number is a free random "solo" number.
  ///
  /// With [mode] = [GenerationMode.mix] each set instead picks one of the
  /// [mixRecipes] at random (e.g. plus-2 + reversed + one plus-10/20/30 pair),
  /// with no shared numbers between patterns. In mix mode Plus 2 and Twin can
  /// each appear twice in the same set. [includePlusStep] only affects
  /// [GenerationMode.allPatterns].
  ///
  /// Combinations containing a run of consecutive numbers longer than
  /// [maxConsecutiveRun] (e.g. 11,12,13,14) are rejected and regenerated.
  /// The default of 2 allows an adjacent pair such as 11,12 but not 11,12,13.
  /// Use 1 to forbid adjacent numbers entirely.
  ///
  /// Historical frequencies are intentionally not used to bias this initial
  /// pattern prototype. Add them only after implementing a fair backtest.
  List<LottoCombination> generate({
    required LottoGame game,
    int count = 1,
    int maxAttemptsPerCombination = 5000,
    int maxConsecutiveRun = 2,
    bool includePlusStep = true,
    GenerationMode mode = GenerationMode.allPatterns,
  }) {
    if (maxConsecutiveRun < 1) {
      throw ArgumentError.value(
        maxConsecutiveRun,
        'maxConsecutiveRun',
        'Must be at least 1.',
      );
    }
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'Must be at least 1.');
    }
    if (maxAttemptsPerCombination < 1) {
      throw ArgumentError.value(
        maxAttemptsPerCombination,
        'maxAttemptsPerCombination',
        'Must be at least 1.',
      );
    }

    return List.generate(count, (_) {
      // Plus 10 / 20 / 30 are separate patterns: one is picked at random per set.
      final step = _pick(LottoCombination.plusSteps);
      for (var attempt = 0; attempt < maxAttemptsPerCombination; attempt++) {
        final combination = mode == GenerationMode.mix
            ? _tryGenerateMix(game, maxConsecutiveRun, step)
            : _tryGenerateOne(game, maxConsecutiveRun, includePlusStep, step);
        if (combination != null) return combination;
      }
      throw StateError(
        'Could not create a valid combination for ${game.displayName}.',
      );
    });
  }

  LottoCombination? _tryGenerateOne(
    LottoGame game,
    int maxConsecutiveRun,
    bool includePlusStep,
    int step,
  ) {
    final plusPairs = <LottoPair>[
      for (var n = game.minNumber; n + 2 <= game.maxNumber; n++)
        (first: n, second: n + 2),
    ];
    final reversePairs = _validReversePairs(game);
    final twins = _validTwins(game);

    if (plusPairs.isEmpty || reversePairs.isEmpty || twins.isEmpty) return null;

    final plus = _pick(plusPairs);
    final occupied = <int>{plus.first, plus.second};

    final availableTwins = twins.where((n) => !occupied.contains(n)).toList();
    if (availableTwins.isEmpty) return null;
    final twin = _pick(availableTwins);
    occupied.add(twin);

    final availableReverses = reversePairs.where(
      (p) => !occupied.contains(p.first) && !occupied.contains(p.second),
    ).toList();
    if (availableReverses.isEmpty) return null;
    final reverse = _pick(availableReverses);
    occupied
      ..add(reverse.first)
      ..add(reverse.second);

    int? solo;
    LottoPair? plusStepPair;
    if (includePlusStep) {
      final candidates = <LottoPair>[];
      for (final anchor in occupied) {
        final up = anchor + step;
        final down = anchor - step;
        if (game.isValidNumber(up) && !occupied.contains(up)) {
          candidates.add((first: anchor, second: up));
        }
        if (game.isValidNumber(down) && !occupied.contains(down)) {
          candidates.add((first: down, second: anchor));
        }
      }
      if (candidates.isEmpty) return null;
      final pair = _pick(candidates);
      plusStepPair = pair;
      occupied
        ..add(pair.first)
        ..add(pair.second);
    } else {
      final solos = [
        for (var n = game.minNumber; n <= game.maxNumber; n++)
          if (!occupied.contains(n)) n,
      ];
      if (solos.isEmpty) return null;
      final value = _pick(solos);
      solo = value;
      occupied.add(value);
    }

    if (occupied.length != game.numbersToDraw) return null;

    final numbers = occupied.toList()..sort();
    if (longestConsecutiveRun(numbers) > maxConsecutiveRun) return null;

    return LottoCombination(
      game: game,
      numbers: numbers,
      plusTwoPair: plus,
      twinNumber: twin,
      reversePair: reverse,
      soloNumber: solo,
      plusStepPair: plusStepPair,
    );
  }

  LottoCombination? _tryGenerateMix(
    LottoGame game,
    int maxConsecutiveRun,
    int step,
  ) {
    final recipe = _pick(mixRecipes);
    final occupied = <int>{};
    final plusTwos = <LottoPair>[];
    final twins = <int>[];
    LottoPair? reverse;
    LottoPair? plusStepPair;
    int? solo;

    // Plus 2 can appear twice in one set (e.g. 17-19 and 52-54).
    for (var i = 0; i < recipe.plusTwo; i++) {
      final options = <LottoPair>[
        for (var n = game.minNumber; n + 2 <= game.maxNumber; n++)
          if (!occupied.contains(n) && !occupied.contains(n + 2))
            (first: n, second: n + 2),
      ];
      if (options.isEmpty) return null;
      final pair = _pick(options);
      plusTwos.add(pair);
      occupied..add(pair.first)..add(pair.second);
    }
    // Twin can appear twice in one set (e.g. 11 and 33).
    for (var i = 0; i < recipe.twin; i++) {
      final options = _validTwins(game).where((n) => !occupied.contains(n)).toList();
      if (options.isEmpty) return null;
      final value = _pick(options);
      twins.add(value);
      occupied.add(value);
    }
    if (recipe.reverse) {
      final options = _validReversePairs(game)
          .where((p) => !occupied.contains(p.first) && !occupied.contains(p.second))
          .toList();
      if (options.isEmpty) return null;
      final pair = _pick(options);
      reverse = pair;
      occupied..add(pair.first)..add(pair.second);
    }
    if (recipe.plusStep) {
      final options = <LottoPair>[
        for (var n = game.minNumber; n + step <= game.maxNumber; n++)
          if (!occupied.contains(n) && !occupied.contains(n + step))
            (first: n, second: n + step),
      ];
      if (options.isEmpty) return null;
      final pair = _pick(options);
      plusStepPair = pair;
      occupied..add(pair.first)..add(pair.second);
    }
    if (recipe.solo) {
      final options = [
        for (var n = game.minNumber; n <= game.maxNumber; n++)
          if (!occupied.contains(n)) n,
      ];
      if (options.isEmpty) return null;
      final value = _pick(options);
      solo = value;
      occupied.add(value);
    }

    if (occupied.length != game.numbersToDraw) return null;

    final numbers = occupied.toList()..sort();
    if (longestConsecutiveRun(numbers) > maxConsecutiveRun) return null;

    return LottoCombination(
      game: game,
      numbers: numbers,
      plusTwoPair: plusTwos.isNotEmpty ? plusTwos[0] : null,
      extraPlusTwoPair: plusTwos.length > 1 ? plusTwos[1] : null,
      twinNumber: twins.isNotEmpty ? twins[0] : null,
      extraTwinNumber: twins.length > 1 ? twins[1] : null,
      reversePair: reverse,
      soloNumber: solo,
      plusStepPair: plusStepPair,
    );
  }

  /// Length of the longest run of consecutive integers in a sorted list.
  /// e.g. [11, 12, 13, 14, 22, 31] -> 4, [5, 7, 8, 20, 30, 31] -> 2.
  static int longestConsecutiveRun(List<int> sortedNumbers) {
    if (sortedNumbers.isEmpty) return 0;
    var longest = 1;
    var current = 1;
    for (var i = 1; i < sortedNumbers.length; i++) {
      if (sortedNumbers[i] == sortedNumbers[i - 1] + 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  List<LottoPair> _validReversePairs(LottoGame game) {
    final pairs = <LottoPair>[];
    for (var n = game.minNumber; n <= game.maxNumber; n++) {
      final text = n.toString().padLeft(2, '0');
      final reversed = int.parse(text.split('').reversed.join());
      if (n < reversed && game.isValidNumber(reversed)) {
        pairs.add((first: n, second: reversed));
      }
    }
    return pairs;
  }

  List<int> _validTwins(LottoGame game) => [
        for (var n = game.minNumber; n <= game.maxNumber; n++)
          if (_isTwin(n)) n,
      ];

  bool _isTwin(int n) {
    final text = n.toString().padLeft(2, '0');
    return text.length == 2 && text[0] == text[1];
  }

  T _pick<T>(List<T> items) => items[_random.nextInt(items.length)];
}
