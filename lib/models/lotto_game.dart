enum LottoGame {
  lotto642(displayName: 'Lotto 6/42', minNumber: 1, maxNumber: 42, numbersToDraw: 6),
  lotto645(displayName: 'Mega Lotto 6/45', minNumber: 1, maxNumber: 45, numbersToDraw: 6),
  lotto649(displayName: 'Super Lotto 6/49', minNumber: 1, maxNumber: 49, numbersToDraw: 6),
  lotto655(displayName: 'Grand Lotto 6/55', minNumber: 1, maxNumber: 55, numbersToDraw: 6),
  lotto658(displayName: 'Ultra Lotto 6/58', minNumber: 1, maxNumber: 58, numbersToDraw: 6);

  const LottoGame({
    required this.displayName,
    required this.minNumber,
    required this.maxNumber,
    required this.numbersToDraw,
  });

  final String displayName;
  final int minNumber;
  final int maxNumber;
  final int numbersToDraw;

  bool isValidNumber(int number) =>
      number >= minNumber && number <= maxNumber;
}
