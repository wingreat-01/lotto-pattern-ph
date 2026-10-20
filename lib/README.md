# Lotto Pattern Generator — Pattern-Based Prototype

This is a starter Dart logic layer for a Flutter Android app. Copy `lib/` and `test/` into a project created with `flutter create`.

## Six-number combination rules
Each generated combination tries to satisfy the user-defined patterns in the same set:

1. **Plus 2:** includes a pair `n` and `n + 2`.
2. **Twin number:** includes one repeated-digit number, such as 11, 22, 33; only values within the selected game's range are allowed.
3. **Reversed pair:** includes both numbers formed by reversing two-digit display forms, e.g. 04 ↔ 40 and 14 ↔ 41.
4. **Plus 10, Plus 20, Plus 30:** three separate patterns (n and n + 10, n + 20 or n + 30, e.g. 9 → 39, 19 → 29, 5 → 25). A set never contains more than one of them: one is chosen at random for each set. In *All patterns* mode the sixth number is the partner of the pair and shares one number with another pattern, so everything fits in six slots. Turn it off with `includePlusStep: false`, and the sixth slot becomes a free random **solo** number instead.
5. **Consecutive limit:** sets with more than `maxConsecutiveRun` (default 2) consecutive numbers, such as 11,12,13,14, are rejected.

The plus-2 pair, twin and reversed pair use exactly 2 + 1 + 2 = 5 slots, and the plus-step (or solo) number fills the sixth. The pairs and twin are selected to avoid number overlap. If no valid combination can be assembled for a game under the rules, the service throws a `StateError` rather than silently returning a combination that violates the rules.

## Mix mode
`generate(game: ..., mode: GenerationMode.mix)` makes each set use a different random mix of patterns instead of all of them. Patterns never share numbers in this mode, and a set has at most one Plus 10/20/30 pair (the step is chosen at random). The four mixes (see `mixRecipes` in `models/generation_mode.dart`) are:

1. Twin + Reversed + Plus 10/20/30 + Solo
2. Plus 2 + Reversed + Plus 10/20/30
3. Plus 2 + Twin + Plus 10/20/30 + Solo
4. Plus 2 + Twin + Reversed + Solo

## Games
- Lotto 6/42: 1–42
- Mega Lotto 6/45: 1–45
- Super Lotto 6/49: 1–49
- Grand Lotto 6/55: 1–55
- Ultra Lotto 6/58: 1–58

Verify current PCSO game names and rules before release.

## Use
```dart
final service = LottoGeneratorService();
final results = service.generate(game: LottoGame.lotto642, count: 5);
for (final result in results) {
  print(result.numbers); // six sorted numbers
  print(result.plusTwoPair);
  print(result.twinNumber);
  print(result.reversePair);
  print(result.soloNumber);
}
```

## Testing
Run `flutter test` after copying the folders into a Flutter project.

## Important
These are pattern-based combinations, not proven predictions. Historical pattern occurrence does not establish an advantage in future random draws. Use verified historical results and out-of-sample backtesting before making performance claims.

## Live results tab
`screens/latest_results_screen.dart` reads results from the official PCSO page via `services/pcso_results_service.dart` and shows the latest draw plus the previous draw day for the selected game, each with detected patterns (`services/pattern_analyzer.dart`). It refreshes every 2 minutes and on pull-to-refresh.

Add to `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.2.0
  html: ^0.15.4
```
PCSO has no public API, so this submits the same search form as the website and parses the table. If PCSO redesigns the page, only `pcso_results_service.dart` needs updating. Android/iOS/desktop only (Flutter Web is blocked by CORS).
