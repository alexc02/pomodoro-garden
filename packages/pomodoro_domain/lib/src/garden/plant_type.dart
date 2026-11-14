import 'season.dart';
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

/// The silhouette a species grows in: one drawing per form and stage.
///
/// A [PlantType] has two or three, so species of a type no longer all share
/// a shape. Named in the art manifest, so renaming a member means renaming
/// its art.
enum PlantForm {
  /// A fan of thin stems, each ending in an open flower.
  posy(PlantType.wildflower),

  /// One tall stem hung with bells up its length.
  spire(PlantType.wildflower),

  /// Stems thick with rounded leaves in pairs.
  leafy(PlantType.herb),

  /// Upright woody stems bristling with needle leaves.
  sprig(PlantType.herb),

  /// One stem and a wide head of petals round a seed head.
  rayed(PlantType.flower),

  /// One stem and a closed cup of overlapping petals.
  cup(PlantType.flower),

  /// A dome of leaf, scattered with flower heads.
  mound(PlantType.bush),

  /// A low cushion with flower spikes standing out of it.
  spiked(PlantType.bush),

  /// A slim trunk under a round crown in blossom.
  orchard(PlantType.smallTree),

  /// A low fork under wide, flat tiers of leaf.
  spreading(PlantType.smallTree),

  /// A heavy trunk under a broad, billowing crown.
  broadleaf(PlantType.largeTree),

  /// A crown that falls in long curtains to the ground.
  weeping(PlantType.largeTree),

  /// A straight trunk and tiers of boughs narrowing to a point.
  conifer(PlantType.largeTree),

  /// The milestone tree, hung with tassels of blossom.
  tassel(PlantType.bonus);

  const PlantForm(this.type);

  final PlantType type;

  /// Every form of [type], in declaration order.
  static List<PlantForm> of(PlantType type) =>
      values.where((form) => form.type == type).toList(growable: false);
}

/// A specific plant within a [PlantType].
///
/// Stored by [name], so renaming a member needs a migration. Adding one is
/// free: gardens keep the species they stored.
enum PlantSpecies {
  poppy(PlantForm.posy, 'Poppy'),
  cornflower(PlantForm.posy, 'Cornflower'),
  buttercup(PlantForm.posy, 'Buttercup'),
  foxglove(PlantForm.spire, 'Foxglove'),
  bluebell(PlantForm.spire, 'Bluebell', season: Season.spring),
  lupin(PlantForm.spire, 'Lupin', season: Season.summer),
  aster(PlantForm.posy, 'Aster', season: Season.autumn),
  snowdrop(PlantForm.posy, 'Snowdrop', season: Season.winter),
  edelweiss(PlantForm.posy, 'Edelweiss', isRare: true),

  basil(PlantForm.leafy, 'Basil'),
  mint(PlantForm.leafy, 'Mint'),
  rosemary(PlantForm.sprig, 'Rosemary'),
  thyme(PlantForm.sprig, 'Thyme'),
  sage(PlantForm.leafy, 'Sage'),
  chives(PlantForm.sprig, 'Chives', season: Season.spring),
  fourLeafClover(PlantForm.leafy, 'Four-leaf clover', isRare: true),

  sunflower(PlantForm.rayed, 'Sunflower'),
  tulip(PlantForm.cup, 'Tulip'),
  daisy(PlantForm.rayed, 'Daisy'),
  peony(PlantForm.cup, 'Peony'),
  crocus(PlantForm.cup, 'Crocus', season: Season.spring),
  rose(PlantForm.cup, 'Rose', season: Season.summer),
  chrysanthemum(PlantForm.rayed, 'Chrysanthemum', season: Season.autumn),
  hellebore(PlantForm.cup, 'Hellebore', season: Season.winter),
  blackTulip(PlantForm.cup, 'Black tulip', isRare: true),

  lavender(PlantForm.spiked, 'Lavender'),
  boxwood(PlantForm.mound, 'Boxwood'),
  hydrangea(PlantForm.mound, 'Hydrangea'),
  azalea(PlantForm.mound, 'Azalea', season: Season.spring),
  heather(PlantForm.spiked, 'Heather', season: Season.autumn),
  holly(PlantForm.mound, 'Holly', season: Season.winter),
  burningBush(PlantForm.mound, 'Burning bush', isRare: true),

  cherryBlossom(PlantForm.orchard, 'Cherry blossom'),
  maple(PlantForm.spreading, 'Maple'),
  olive(PlantForm.spreading, 'Olive'),
  magnolia(PlantForm.orchard, 'Magnolia', season: Season.spring),
  rowan(PlantForm.orchard, 'Rowan', season: Season.autumn),
  ginkgo(PlantForm.spreading, 'Ginkgo', isRare: true),

  oak(PlantForm.broadleaf, 'Oak'),
  willow(PlantForm.weeping, 'Willow'),
  pine(PlantForm.conifer, 'Pine'),
  birch(PlantForm.broadleaf, 'Birch'),
  beech(PlantForm.broadleaf, 'Beech', season: Season.autumn),
  spruce(PlantForm.conifer, 'Spruce', season: Season.winter),
  sequoia(PlantForm.conifer, 'Sequoia', isRare: true),

  // Milestone plants, one per milestone in order. Named by [Milestone], never
  // picked via [chosenFor].
  bonsai(PlantForm.tassel, 'Bonsai tree'),
  wisteriaArch(PlantForm.tassel, 'Wisteria arch'),
  japaneseMaple(PlantForm.tassel, 'Japanese maple'),
  ancientOak(PlantForm.tassel, 'Ancient oak'),
  cherryBlossomGrove(PlantForm.tassel, 'Cherry blossom grove'),
  enchantedWillow(PlantForm.tassel, 'Enchanted willow'),
  goldenGarden(PlantForm.tassel, 'Golden garden');

  const PlantSpecies(
    this.form,
    this.label, {
    this.season,
    this.isRare = false,
  });

  /// The drawing it shares with the other species of its form.
  final PlantForm form;

  final String label;

  /// The only season it grows in. Null grows all year.
  final Season? season;

  /// Grown by roughly one session in [oneInThisManyIsRare] instead of taking
  /// an even turn with the rest of its type.
  final bool isRare;

  PlantType get type => form.type;

  /// How often a session grows a rare species, where its type has one.
  static const int oneInThisManyIsRare = 10;

  /// Every species of [type], in declaration order.
  static List<PlantSpecies> of(PlantType type) =>
      values.where((species) => species.type == type).toList(growable: false);

  /// The species of [type] a session in [season] can grow. A null [season]
  /// leaves out everything seasonal. Never empty: every type has species that
  /// grow all year.
  static List<PlantSpecies> growingIn(PlantType type, Season? season) =>
      values
          .where(
            (species) =>
                species.type == type &&
                (species.season == null || species.season == season),
          )
          .toList(growable: false);

  /// Deterministic from [seed] (the session id) and [season] so a plant is
  /// always the same species.
  ///
  /// The rare draw is its own roll of the seed, so adding a common species
  /// doesn't change which sessions were rare.
  static PlantSpecies chosenFor({
    required PlantType type,
    required String seed,
    Season? season,
  }) {
    final growing = growingIn(type, season);
    final rare = [
      for (final species in growing)
        if (species.isRare) species,
    ];
    if (rare.isNotEmpty &&
        stableFraction('$seed/rare') * oneInThisManyIsRare < 1) {
      return stableChoice(rare, seed);
    }

    return stableChoice(
      [
        for (final species in growing)
          if (!species.isRare) species,
      ],
      seed,
    );
  }
}
