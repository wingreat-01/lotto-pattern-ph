/// How combinations are assembled.
enum GenerationMode {
  /// Every set contains Plus 2, Twin and Reversed, plus one random
  /// Plus 10 / 20 / 30 pair (or a free solo number if that pattern is off).
  allPatterns('All patterns', 'Every set uses Plus 2, Twin, Reversed and one random Plus 10/20/30'),

  /// Each set picks a different random mix of patterns.
  mix('Mix', 'Each set picks a different mix of patterns');

  const GenerationMode(this.label, this.description);
  final String label;
  final String description;
}

/// One way to fill exactly six slots without overlapping patterns.
///
/// Slots: plusTwo = 2 each, reverse = 2, plusStep = 2, twin = 1 each, solo = 1.
/// Plus 2 and Twin can each appear up to TWICE in one set (e.g. 17-19 and
/// 52-54, or twins 11 and 33). [plusStep] stands for ONE of the three separate
/// patterns Plus 10, Plus 20 or Plus 30. Which one is chosen at random for
/// every set, and a set never contains more than one of them.
class MixRecipe {
  const MixRecipe({
    this.plusTwo = 0,
    this.twin = 0,
    this.reverse = false,
    this.plusStep = false,
    this.solo = false,
  });

  /// How many Plus 2 pairs (0, 1 or 2).
  final int plusTwo;

  /// How many Twin numbers (0, 1 or 2).
  final int twin;
  final bool reverse;
  final bool plusStep;
  final bool solo;

  int get slots =>
      plusTwo * 2 + twin + (reverse ? 2 : 0) + (plusStep ? 2 : 0) + (solo ? 1 : 0);
}

/// Every way to reach exactly six slots (Plus 2 and Twin up to twice, the
/// other patterns at most once).
const mixRecipes = <MixRecipe>[
  MixRecipe(twin: 1, reverse: true, plusStep: true, solo: true),
  MixRecipe(plusTwo: 1, reverse: true, plusStep: true),
  MixRecipe(plusTwo: 1, twin: 1, plusStep: true, solo: true),
  MixRecipe(plusTwo: 1, twin: 1, reverse: true, solo: true),
  // Doubled Plus 2 and/or doubled Twin.
  MixRecipe(twin: 2, reverse: true, plusStep: true),
  MixRecipe(plusTwo: 1, twin: 2, plusStep: true),
  MixRecipe(plusTwo: 1, twin: 2, reverse: true),
  MixRecipe(plusTwo: 2, plusStep: true),
  MixRecipe(plusTwo: 2, reverse: true),
  MixRecipe(plusTwo: 2, twin: 1, solo: true),
  MixRecipe(plusTwo: 2, twin: 2),
];
