import 'plant_type.dart';

/// A count of completed sessions that earns a bonus plant: REQ-021.
///
/// Seven of them, and the long-horizon reason to keep coming back — the
/// thousandth session is years of work and the plant that marks it says so.
///
/// Two things about how they are written down are load-bearing:
///
/// **A milestone is identified by its [sessions], not by its name.** That
/// integer is what PRD §4.3 stores as `milestoneSessions` and what a stored
/// plant is read back through, so renaming a member below costs nothing and
/// changing a number is a migration. It is also what makes the awarding
/// idempotent at the level of the database rather than only in the code that
/// calls it — one row per milestone, enforced by a unique index.
///
/// **They are evaluated against the total, never against a crossing.** [dueFrom]
/// asks which milestones a count has *reached* and which of those have not been
/// awarded, so a user arriving at this build with thirty sessions behind them
/// collects the ten and the twenty-five rather than nothing, and a check that
/// runs twice hands out nothing the second time. Nothing here fires at a
/// threshold, for the same reason nothing in this package fires at the end of a
/// session: an app that was asleep when the number went past would have missed
/// it for good.
enum Milestone {
  ten(10, PlantSpecies.bonsai),
  twentyFive(25, PlantSpecies.wisteriaArch),
  fifty(50, PlantSpecies.japaneseMaple),
  oneHundred(100, PlantSpecies.ancientOak),
  twoHundredAndFifty(250, PlantSpecies.cherryBlossomGrove),
  fiveHundred(500, PlantSpecies.enchantedWillow),
  oneThousand(1000, PlantSpecies.goldenGarden);

  const Milestone(this.sessions, this.species);

  /// How many completed sessions earn this one. Ascending down the list, which
  /// is what lets [reachedBy] stop at the first one out of reach.
  final int sessions;

  /// The plant it awards. Always of [PlantType.bonus].
  final PlantSpecies species;

  /// What to call this milestone in front of the user: "10 sessions".
  String get label => '$sessions ${sessions == 1 ? 'session' : 'sessions'}';

  /// Every milestone [completedSessions] has reached, in ascending order.
  ///
  /// The whole count, not the last step of it. A user who has done thirty
  /// sessions has reached two milestones whether the app was watching or not.
  static List<Milestone> reachedBy(int completedSessions) {
    final reached = <Milestone>[];
    for (final milestone in values) {
      if (completedSessions < milestone.sessions) break;
      reached.add(milestone);
    }
    return List.unmodifiable(reached);
  }

  /// The milestones [completedSessions] has reached that [awarded] does not
  /// already hold, in ascending order.
  ///
  /// This is the whole of the awarding rule, and it is a set difference rather
  /// than a comparison against a stored high-water mark on purpose: the answer
  /// is the same however many times it is asked, and it is derived from the
  /// plants actually in the ground rather than from a counter that could
  /// disagree with them.
  static List<Milestone> dueFrom({
    required int completedSessions,
    required Set<Milestone> awarded,
  }) =>
      List.unmodifiable(
        reachedBy(completedSessions).where((m) => !awarded.contains(m)),
      );

  /// The milestone stored as [sessions], or null if no milestone has that
  /// count.
  ///
  /// Null rather than throwing, because the caller is a database read: a row
  /// written by a build whose milestones differed is a row from another version,
  /// and a plant that cannot say which milestone earned it is better than a
  /// garden that will not open.
  static Milestone? withSessions(int sessions) {
    for (final milestone in values) {
      if (milestone.sessions == sessions) return milestone;
    }
    return null;
  }
}
