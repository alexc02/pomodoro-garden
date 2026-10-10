import 'stable_choice.dart';

/// What a session grows, decided by how long the session was: REQ-015.
///
/// The bands are declared here once, in ascending order, and
/// [forSessionLength] walks them. Writing the table down as data rather than as
/// a chain of `if`s is what lets a test assert the boundaries against the same
/// numbers the mapping uses, and what makes "which band is a 40-minute session
/// in" answerable by reading one line.
///
/// Ticket 13's [bonus] is a member of this enum and of nothing else: PRD §4.3
/// stores a plant's type as one text column, and a milestone plant is a plant.
/// It is *not* a band — it has no [shortestSession], no session length reaches
/// it, and [forSessionLength] walks [grownBySessions] rather than [values] so
/// that nothing about it can leak into a mapping from duration.
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

  /// 75–120 minutes. Grand, and the dominant feature of a garden.
  largeTree(Duration(minutes: 75), 'Large tree'),

  /// REQ-021's milestone plants: a bonsai, a wisteria arch, an ancient oak.
  ///
  /// Last, and bandless. A bonus plant is earned by a *count* of completed
  /// sessions rather than by the length of any one of them — see [Milestone] —
  /// so there is no duration that grows one and no place for it in the
  /// ascending table above.
  bonus(null, 'Bonus plant');

  const PlantType(this.shortestSession, this.label);

  /// The shortest session that grows this type. Inclusive: a session of exactly
  /// this length grows this plant, and a session a millisecond short of it
  /// grows the one below.
  ///
  /// Null for [bonus], which no session length grows.
  final Duration? shortestSession;

  /// What to call this type in front of the user.
  final String label;

  /// The six types a session length can grow, in ascending order.
  ///
  /// [values] minus [bonus], and the list [forSessionLength] actually walks.
  /// Derived rather than written out a second time, so adding a band adds it
  /// here too and adding a bandless type cannot accidentally become reachable
  /// from a duration.
  static final List<PlantType> grownBySessions = List.unmodifiable(
    values.where((type) => type.shortestSession != null),
  );

  /// The type a session of [plannedDuration] grows.
  ///
  /// Total, on purpose. REQ-030 keeps session lengths between 5 and 120
  /// minutes, so the ends of this range are unreachable from the settings — but
  /// a stored row from a build with different bounds, or a caller that has not
  /// clamped, still has to get a plant rather than an exception. Below the
  /// first band is the smallest plant; above the last is the largest.
  static PlantType forSessionLength(Duration plannedDuration) {
    var grown = grownBySessions.first;
    for (final type in grownBySessions) {
      if (plannedDuration < type.shortestSession!) break;
      grown = type;
    }
    return grown;
  }
}

/// The particular plant within a [PlantType]: which herb, which flower.
///
/// Species carries no behaviour beyond its name and its type. It exists so that
/// two 25-minute sessions do not grow the same sunflower twice over, and so
/// ticket 12's card has something specific to say.
///
/// Stored by [name], so renaming a member orphans the rows that hold the old
/// one. Add members freely; rename them with a migration.
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

  // REQ-021's seven, one per milestone and in milestone order. Unlike every
  // species above them these are never *chosen* — [Milestone] names the one it
  // awards, so [chosenFor] is not how a garden ever comes by one.
  bonsai(PlantType.bonus, 'Bonsai tree'),
  wisteriaArch(PlantType.bonus, 'Wisteria arch'),
  japaneseMaple(PlantType.bonus, 'Japanese maple'),
  ancientOak(PlantType.bonus, 'Ancient oak'),
  cherryBlossomGrove(PlantType.bonus, 'Cherry blossom grove'),
  enchantedWillow(PlantType.bonus, 'Enchanted willow'),
  goldenGarden(PlantType.bonus, 'Golden garden');

  const PlantSpecies(this.type, this.label);

  /// The type this species is one of.
  final PlantType type;

  /// What to call this species in front of the user — ticket 12 sets it in the
  /// handwritten botanical face.
  final String label;

  /// Every species of [type], in declaration order.
  static List<PlantSpecies> of(PlantType type) =>
      values.where((species) => species.type == type).toList(growable: false);

  /// The species [seed] selects from [type].
  ///
  /// Deterministic, and that is the requirement rather than an optimisation: a
  /// plant is watched growing for up to two hours and then looked at again for
  /// months, and it has to be the same species every time it is drawn. Seeding
  /// from the session's id gives that for free — the choice is made once, when
  /// the id is minted, and every later ask re-derives the same answer instead
  /// of rolling again.
  static PlantSpecies chosenFor({
    required PlantType type,
    required String seed,
  }) =>
      stableChoice(of(type), seed);
}
