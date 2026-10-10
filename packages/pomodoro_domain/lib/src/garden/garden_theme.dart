/// REQ-034's three biomes: which garden the user's plants are standing in.
///
/// An enum rather than a string, and in the domain rather than beside the
/// colours, because what hangs off it is not about colour at all — which one
/// the garden falls back to when a stored row names a biome this build has
/// never heard of. That is a rule, and a rule is not the business of a palette.
///
/// **All three are everybody's.** An earlier draft of this app sold two of
/// them; the app is free and there is nothing here to own — see
/// `docs/adr/0021-…`.
///
/// **A theme is not a season, and the two compose.** A season is read off the
/// device's date and cannot be chosen; a theme is chosen and never changes on
/// its own. Every one of these renders in all four seasons — twelve
/// combinations, and `SeasonPalette.of` is the table of them.
enum GardenTheme {
  /// The default, and the only one a first run can be on: raked sand, stone and
  /// moss, kept deliberately quiet.
  ///
  /// It is the garden every screenshot of this app has ever shown — §5.1's
  /// palette *is* Zen's summer.
  zen(
    'Zen Garden',
    'Raked sand, stone and moss. Quiet by design.',
  ),

  /// Warm glass and deep leaf: a garden under cover, where the light is green
  /// before it reaches the ground.
  tropical(
    'Tropical Greenhouse',
    'Warm glass and deep leaf, humid all year round.',
  ),

  /// Open grass gone to seed, with colour scattered through it rather than
  /// arranged.
  wildflower(
    'Wildflower Meadow',
    'Open grass gone to seed, colour scattered through it.',
  ),
  ;

  const GardenTheme(this.label, this.blurb);

  /// What the picker calls this theme.
  final String label;

  /// The line under the name in the picker.
  ///
  /// Carried here rather than written on the screen so that nothing describing
  /// a theme has to write its own sentence about it.
  final String blurb;

  /// What a first run starts on, and what an unreadable stored name reads as.
  ///
  /// Named rather than written as [zen] at the call sites, so that the default
  /// theme is one decision in one place rather than a constant repeated
  /// wherever a fallback is needed.
  static const GardenTheme fallback = zen;

  /// The theme called [name], or [fallback] if this build has never heard of
  /// it.
  ///
  /// Falls back rather than throwing, on the same reasoning `AmbientSound.named`
  /// does: the name arrives from a stored row, and a row written by a build that
  /// offered a theme this one does not is a row to read as best it can be read.
  /// Zen is the answer that cannot be wrong — it is what a user who has chosen
  /// nothing gets.
  static GardenTheme named(String name) => values.firstWhere(
        (theme) => theme.name == name,
        orElse: () => fallback,
      );
}
