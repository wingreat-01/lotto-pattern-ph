import 'package:flutter_test/flutter_test.dart';

import '../lib/models/generation_mode.dart';
import '../lib/models/lotto_combination.dart';
import '../lib/models/lotto_game.dart';
import '../lib/services/lotto_generator_service.dart';

void main() {
  group('LottoGeneratorService', () {
    final service = LottoGeneratorService();

    test('has the expected six-number game ranges', () {
      expect(LottoGame.lotto642.maxNumber, 42);
      expect(LottoGame.lotto645.maxNumber, 45);
      expect(LottoGame.lotto649.maxNumber, 49);
      expect(LottoGame.lotto655.maxNumber, 55);
      expect(LottoGame.lotto658.maxNumber, 58);
      for (final game in LottoGame.values) {
        expect(game.numbersToDraw, 6);
        expect(game.minNumber, 1);
      }
    });

    test('generates six distinct sorted valid numbers for every game', () {
      for (final game in LottoGame.values) {
        final results = service.generate(game: game, count: 100);
        for (final result in results) {
          expect(result.numbers.length, 6);
          expect(result.numbers.toSet().length, 6);
          expect(result.numbers, [...result.numbers]..sort());
          expect(result.numbers.every(game.isValidNumber), isTrue);
        }
      }
    });

    test('every result includes the core patterns', () {
      for (final game in LottoGame.values) {
        final results = service.generate(game: game, count: 100);
        for (final result in results) {
          expect(result.numbers, contains(result.plusTwoPair!.first));
          expect(result.numbers, contains(result.plusTwoPair!.second));
          expect(result.plusTwoPair!.second - result.plusTwoPair!.first, 2);

          final twinText = result.twinNumber.toString().padLeft(2, '0');
          expect(twinText[0], twinText[1]);
          expect(result.numbers, contains(result.twinNumber));

          final reversedText = result.reversePair!.first
              .toString()
              .padLeft(2, '0')
              .split('')
              .reversed
              .join();
          expect(int.parse(reversedText), result.reversePair!.second);
          expect(result.numbers, contains(result.reversePair!.first));
          expect(result.numbers, contains(result.reversePair!.second));

          if (result.soloNumber != null) {
            expect(result.numbers, contains(result.soloNumber));
          } else {
            expect(result.plusStepPair, isNotNull);
          }
        }
      }
    });

    test('plus 10/20/30 pair is included by default', () {
      for (final game in LottoGame.values) {
        final results = service.generate(game: game, count: 200);
        for (final result in results) {
          final pair = result.plusStepPair;
          expect(pair, isNotNull);
          expect(result.soloNumber, isNull);
          expect([10, 20, 30], contains(pair!.second - pair.first));
          expect(result.numbers, contains(pair.first));
          expect(result.numbers, contains(pair.second));
          expect(result.numbers.length, 6);
          expect(result.numbers.toSet().length, 6);
        }
      }
    });

    test('Plus 10, Plus 20 and Plus 30 are each picked about equally', () {
      for (final game in LottoGame.values) {
        final results = service.generate(game: game, count: 900);
        final counts = <int, int>{10: 0, 20: 0, 30: 0};
        for (final r in results) {
          counts[r.plusStep!] = counts[r.plusStep!]! + 1;
        }
        for (final step in [10, 20, 30]) {
          expect(counts[step]!, greaterThan(200), reason: '$game plus $step');
        }
      }
    });

    test('includePlusStep: false keeps a free solo number', () {
      final results = service.generate(
        game: LottoGame.lotto642,
        count: 100,
        includePlusStep: false,
      );
      for (final result in results) {
        expect(result.plusStepPair, isNull);
        expect(result.soloNumber, isNotNull);
        expect(result.numbers, contains(result.soloNumber));
      }
    });

    test('plus-step combinations still respect the consecutive-run limit', () {
      final results = service.generate(game: LottoGame.lotto649, count: 300);
      for (final result in results) {
        expect(
          LottoGeneratorService.longestConsecutiveRun(result.numbers),
          lessThanOrEqualTo(2),
        );
      }
    });

    test('supports leading-zero reverse pair 04 and 40 in 6/42', () {
      final game = LottoGame.lotto642;
      final service = LottoGeneratorService();
      final results = service.generate(game: game, count: 300);
      expect(
        results.any((r) =>
            r.reversePair?.first == 4 && r.reversePair?.second == 40),
        isTrue,
      );
    });

    test('does not allow out-of-range reverse pairs', () {
      final results = service.generate(game: LottoGame.lotto642, count: 100);
      for (final result in results) {
        expect(result.numbers.every((n) => n >= 1 && n <= 42), isTrue);
        expect(result.numbers, isNot(contains(61)));
      }
    });

    test('computes the longest consecutive run', () {
      expect(
        LottoGeneratorService.longestConsecutiveRun([11, 12, 13, 14, 22, 31]),
        4,
      );
      expect(
        LottoGeneratorService.longestConsecutiveRun([5, 7, 8, 20, 30, 31]),
        2,
      );
      expect(
        LottoGeneratorService.longestConsecutiveRun([1, 5, 9, 20, 30, 40]),
        1,
      );
    });

    test('never produces more than 2 consecutive numbers by default', () {
      for (final game in LottoGame.values) {
        final results = service.generate(game: game, count: 500);
        for (final result in results) {
          expect(
            LottoGeneratorService.longestConsecutiveRun(result.numbers),
            lessThanOrEqualTo(2),
            reason: '${result.numbers}',
          );
        }
      }
    });

    test('maxConsecutiveRun: 1 forbids adjacent numbers', () {
      final results = service.generate(
        game: LottoGame.lotto645,
        count: 300,
        maxConsecutiveRun: 1,
      );
      for (final result in results) {
        expect(LottoGeneratorService.longestConsecutiveRun(result.numbers), 1);
      }
    });

    test('rejects maxConsecutiveRun less than one', () {
      expect(
        () => service.generate(
          game: LottoGame.lotto642,
          count: 1,
          maxConsecutiveRun: 0,
        ),
        throwsArgumentError,
      );
    });

    group('mix mode', () {
      List<LottoCombination> mixOf(LottoGame game, int count) =>
          service.generate(game: game, count: count, mode: GenerationMode.mix);

      test('generates valid sets for every game', () {
        for (final game in LottoGame.values) {
          for (final r in mixOf(game, 300)) {
            expect(r.numbers.length, 6);
            expect(r.numbers.toSet().length, 6);
            expect(r.numbers.every(game.isValidNumber), isTrue);
            expect(r.numbers, [...r.numbers]..sort());
          }
        }
      });

      test('uses a variety of pattern mixes', () {
        final signatures = <String>{};
        for (final r in mixOf(LottoGame.lotto649, 400)) {
          signatures.add([
            r.plusTwoPairs.length,
            r.twinNumbers.length,
            r.reversePair != null,
            r.plusStepPair != null,
            r.soloNumber != null,
          ].join(','));
        }
        expect(signatures.length, mixRecipes.length);
      });

      test('every set matches one of the recipes and has no shared numbers', () {
        for (final r in mixOf(LottoGame.lotto642, 300)) {
          final slots = r.plusTwoPairs.length * 2 +
              r.twinNumbers.length +
              (r.reversePair != null ? 2 : 0) +
              (r.plusStepPair != null ? 2 : 0) +
              (r.soloNumber != null ? 1 : 0);
          expect(slots, 6);
          final pair = r.plusStepPair;
          if (pair != null) {
            expect([10, 20, 30], contains(pair.second - pair.first));
          }
        }
      });

      test('Plus 2 can appear twice and Twin can appear twice', () {
        final sets = mixOf(LottoGame.lotto649, 600);
        final doublePlusTwo = sets.where((r) => r.plusTwoPairs.length == 2).toList();
        final doubleTwin = sets.where((r) => r.twinNumbers.length == 2).toList();
        expect(doublePlusTwo, isNotEmpty);
        expect(doubleTwin, isNotEmpty);
        for (final r in doublePlusTwo) {
          for (final pair in r.plusTwoPairs) {
            expect(pair.second - pair.first, 2);
            expect(r.numbers, containsAll([pair.first, pair.second]));
          }
        }
        for (final r in doubleTwin) {
          expect(r.twinNumbers.toSet().length, 2);
          for (final t in r.twinNumbers) {
            expect(t % 11, 0);
            expect(r.numbers, contains(t));
          }
        }
      });

      test('picks one of Plus 10 / 20 / 30 at random, never more than one', () {
        final counts = <int, int>{10: 0, 20: 0, 30: 0};
        for (final r in mixOf(LottoGame.lotto649, 900)) {
          final step = r.plusStep;
          if (step != null) counts[step] = counts[step]! + 1;
        }
        // About 3/4 of mixes contain a step; each step should be ~225 of 900.
        for (final step in [10, 20, 30]) {
          expect(counts[step]!, greaterThan(100), reason: 'plus $step');
        }
      });

      test('respects the consecutive-run limit', () {
        for (final game in LottoGame.values) {
          for (final r in mixOf(game, 300)) {
            expect(
              LottoGeneratorService.longestConsecutiveRun(r.numbers),
              lessThanOrEqualTo(2),
            );
          }
        }
      });
    });

    test('rejects count less than one', () {
      expect(
        () => service.generate(game: LottoGame.lotto642, count: 0),
        throwsArgumentError,
      );
    });
  });
}
