/// Garden biome. All three are free (ADR 0005).
///
/// Independent of [Season]: every theme renders in all four seasons (see
/// `SeasonPalette.of`).
enum GardenTheme {
  /// Default. Raked sand, stone and moss.
  zen(
    'Zen Garden',
    'Raked sand, stone and moss. Quiet by design.',
  ),

  tropical(
    'Tropical Greenhouse',
    'Warm glass and deep leaf, humid all year round.',
  ),

  wildflower(
    'Wildflower Meadow',
    'Open grass gone to seed, colour scattered through it.',
  ),
  ;

  const GardenTheme(this.label, this.blurb);

  final String label;

  /// Shown under the name in the picker.
  final String blurb;

  /// First-run default, and what unknown stored names read as.
  static const GardenTheme fallback = zen;

  /// Falls back to [fallback] for names this build doesn't know.
  static GardenTheme named(String name) => values.firstWhere(
        (theme) => theme.name == name,
        orElse: () => fallback,
      );
}
