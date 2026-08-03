import 'stable_choice.dart';

/// Plant category, picked by session length.
///
/// [bonus] (milestone plants) lives here too since it's stored in the same
/// column, but it has no band and [forSessionLength] skips it.
enum PlantType {
  /// 5–14 minutes. Small, colourful, quick to bloom.
  wildflower(Duration(minutes: 5), 'Wildflower'),

  /// 15–24 minutes. Medium, textured leaves.
  herb(Duration(minutes: 15), 'Herb'),

  /// 25–34 minutes. Tall, vibrant bloom.
  flower(Duration(minutes: 25), 'Flower'),

  /// 35–49 minutes. Dense, leafy, medium height.
  bush(Duration(minutes: 35), 'Bush'),

  /// 50–74 minutes. Structural, seasonal colour.
  smallTree(Duration(minutes: 50), 'Small tree'),

  /// 75–120 minutes.
  largeTree(Duration(minutes: 75), 'Large tree'),

  /// Milestone plants. No duration band.
  bonus(null, 'Bonus plant');

  const PlantType(this.shortestSession, this.label);

  /// Inclusive lower bound. Null for [bonus].
  final Duration? shortestSession;

  final String label;

  /// [values] without [bonus], ascending.
  static final List<PlantType> grownBySessions = List.unmodifiable(
    values.where((type) => type.shortestSession != null),
  );

  /// Never throws: lengths outside 5 to 120 min (old rows, unclamped
  /// callers) get the smallest or largest type.
  static PlantType forSessionLength(Duration plannedDuration) {
    var grown = grownBySessions.first;
    for (final type in grownBySessions) {
      if (plannedDuration < type.shortestSession!) break;
      grown = type;
    }
    return grown;
  }
}

/// A specific plant within a [PlantType].
///
/// Stored by [name], so renaming a member needs a migration.
enum PlantSpecies {
  poppy(PlantType.wildflower, 'Poppy'),
  cornflower(PlantType.wildflower, 'Cornflower'),
  buttercup(PlantType.wildflower, 'Buttercup'),

  basil(PlantType.herb, 'Basil'),
  mint(PlantType.herb, 'Mint'),
  rosemary(PlantType.herb, 'Rosemary'),

  sunflower(PlantType.flower, 'Sunflower'),
  tulip(PlantType.flower, 'Tulip'),
  daisy(PlantType.flower, 'Daisy'),

  lavender(PlantType.bush, 'Lavender'),
  boxwood(PlantType.bush, 'Boxwood'),
  hydrangea(PlantType.bush, 'Hydrangea'),

  cherryBlossom(PlantType.smallTree, 'Cherry blossom'),
  maple(PlantType.smallTree, 'Maple'),

  oak(PlantType.largeTree, 'Oak'),
  willow(PlantType.largeTree, 'Willow'),
  pine(PlantType.largeTree, 'Pine'),

  // Milestone plants, one per milestone in order. Named by [Milestone], never
  // picked via [chosenFor].
  bonsai(PlantType.bonus, 'Bonsai tree'),
  wisteriaArch(PlantType.bonus, 'Wisteria arch'),
  japaneseMaple(PlantType.bonus, 'Japanese maple'),
  ancientOak(PlantType.bonus, 'Ancient oak'),
  cherryBlossomGrove(PlantType.bonus, 'Cherry blossom grove'),
  enchantedWillow(PlantType.bonus, 'Enchanted willow'),
  goldenGarden(PlantType.bonus, 'Golden garden');

  const PlantSpecies(this.type, this.label);

  final PlantType type;

  final String label;

  /// Every species of [type], in declaration order.
  static List<PlantSpecies> of(PlantType type) =>
      values.where((species) => species.type == type).toList(growable: false);

  /// Deterministic from [seed] (the session id) so a plant is always the same
  /// species.
  static PlantSpecies chosenFor({
    required PlantType type,
    required String seed,
  }) =>
      stableChoice(of(type), seed);
}
