import 'lotto_game.dart';

/// One official draw: the six winning numbers for [game] on [drawDate].
class DrawResult {
  const DrawResult({
    required this.game,
    required this.numbers,
    required this.drawDate,
    this.jackpot,
    this.winners,
  });

  final LottoGame game;

  /// Winning numbers sorted ascending (draw order is not needed for patterns).
  final List<int> numbers;
  final DateTime drawDate;
  final String? jackpot;
  final int? winners;
}
