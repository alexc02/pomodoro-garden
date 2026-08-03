import 'plant_type.dart';

/// Completed-session counts that award a bonus plant.
///
/// Identified by [sessions] (that's what is stored), so renaming members is
/// free but changing a number needs a migration. Evaluated against the total
/// rather than on crossing a threshold, so missed ones still get awarded and
/// re-checking is harmless.
enum Milestone {
  ten(10, PlantSpecies.bonsai),
  twentyFive(25, PlantSpecies.wisteriaArch),
  fifty(50, PlantSpecies.japaneseMaple),
  oneHundred(100, PlantSpecies.ancientOak),
  twoHundredAndFifty(250, PlantSpecies.cherryBlossomGrove),
  fiveHundred(500, PlantSpecies.enchantedWillow),
  oneThousand(1000, PlantSpecies.goldenGarden);

  const Milestone(this.sessions, this.species);

  /// Ascending; [reachedBy] relies on that.
  final int sessions;

  /// Always [PlantType.bonus].
  final PlantSpecies species;

  /// e.g. "10 sessions".
  String get label => '$sessions ${sessions == 1 ? 'session' : 'sessions'}';

  /// Ascending.
  static List<Milestone> reachedBy(int completedSessions) {
    final reached = <Milestone>[];
    for (final milestone in values) {
      if (completedSessions < milestone.sessions) break;
      reached.add(milestone);
    }
    return List.unmodifiable(reached);
  }

  /// Reached but not yet awarded, ascending. A set difference, so asking twice
  /// gives the same answer.
  static List<Milestone> dueFrom({
    required int completedSessions,
    required Set<Milestone> awarded,
  }) =>
      List.unmodifiable(
        reachedBy(completedSessions).where((m) => !awarded.contains(m)),
      );

  /// Null for unknown counts (rows from another version) instead of throwing.
  static Milestone? withSessions(int sessions) {
    for (final milestone in values) {
      if (milestone.sessions == sessions) return milestone;
    }
    return null;
  }
}
