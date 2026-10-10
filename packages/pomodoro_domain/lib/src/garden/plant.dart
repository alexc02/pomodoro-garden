import '../session/focus_session.dart';
import 'garden_plot.dart';
import 'growth_stage.dart';
import 'milestone.dart';
import 'plant_type.dart';

/// What a running session is growing, at one instant.
///
/// Derived, never stored. Everything here is a function of the session and how
/// far through it is, which is what makes the plant on screen and the plant in
/// the garden the same plant: they are computed from the same session by the
/// same rules, rather than one being handed to the other.
///
/// In particular the species is derived from the session's id, so it is decided
/// the moment the seed drops and cannot drift while the user watches.
final class PlantGrowth {
  const PlantGrowth({
    required this.type,
    required this.species,
    required this.stage,
    required this.sessionId,
  });

  /// What [session] looks like [progress] of the way through it.
  factory PlantGrowth.forSession(
    FocusSession session, {
    required double progress,
  }) {
    final type = PlantType.forSessionLength(session.plannedDuration);
    return PlantGrowth(
      type: type,
      species: PlantSpecies.chosenFor(type: type, seed: session.id),
      stage: GrowthStage.forProgress(progress),
      sessionId: session.id,
    );
  }

  /// The band the session's length puts it in.
  final PlantType type;

  /// Which plant of that band this one is.
  final PlantSpecies species;

  /// How grown it looks right now.
  final GrowthStage stage;

  /// The session growing this plant, and the seed every arbitrary-looking
  /// choice about it is derived from. Carried so the view can offset an ambient
  /// animation per plant without inventing an identity of its own.
  final String sessionId;

  /// Compares by value, so a tick that did not change the stage does not
  /// repaint the plant.
  @override
  bool operator ==(Object other) =>
      other is PlantGrowth &&
      other.type == type &&
      other.species == species &&
      other.stage == stage &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(type, species, stage, sessionId);

  @override
  String toString() => 'PlantGrowth(${species.name}, ${stage.name})';
}

/// A plant in the garden: what one completed session left behind.
///
/// The stored counterpart of [PlantGrowth]. Where the garden is concerned this
/// is the record — the type, the species and the stage are written down rather
/// than re-derived, so ticket 23 can change what a species looks like and
/// ticket 07 can lay a garden out without every read re-running the growth
/// rules over a session row.
final class Plant {
  const Plant({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.species,
    required this.stage,
    required this.plantedAt,
    required this.sessionDuration,
    this.milestone,
    this.plot,
  });

  /// The plant [session] earned, standing in [plot].
  ///
  /// Throws an [ArgumentError] if the session did not complete. Completion is
  /// the only outcome that earns a plant — a cancelled or voided session leaves
  /// nothing — and a caller that reached here with an unfinished session has a
  /// bug that would otherwise show up as a garden full of work nobody did.
  ///
  /// [plot] is chosen by the caller rather than here, because choosing it needs
  /// to know what the rest of the garden looks like and a session does not —
  /// see [GardenPlots.nextFree]. A null plot is a full garden, not a mistake.
  factory Plant.fromSession(
    FocusSession session, {
    required String id,
    GardenPlot? plot,
  }) {
    if (!session.completed) {
      throw ArgumentError.value(
        session,
        'session',
        'only a completed session earns a plant',
      );
    }

    final growth = PlantGrowth.forSession(session, progress: 1);

    return Plant(
      id: id,
      sessionId: session.id,
      type: growth.type,
      species: growth.species,
      stage: growth.stage,
      // The anchor, not the end: the seed went into the soil when the session
      // began. A session started at 23:50 and finished at 00:15 belongs to the
      // evening the user remembers working, not to the next day.
      plantedAt: session.startedAt,
      sessionDuration: session.plannedDuration,
      plot: plot,
    );
  }

  /// The plant [milestone] awards, standing in [plot].
  ///
  /// REQ-021. No session grew this one, so it has no [sessionId] and no
  /// [sessionDuration] — what it has instead is the milestone, which is both
  /// what the card shows and the thing the garden is asked about when deciding
  /// whether this award has already been made.
  ///
  /// [plantedAt] is the instant the award was made rather than the anchor of
  /// any session, because there is no session to anchor to: the thousandth
  /// completed session earned it, but the plant belongs to the day the user was
  /// given it.
  ///
  /// [plot] is the caller's, on the same terms as [fromSession]: a null plot is
  /// a full garden. It is the case ADR 0006 already covers — the plant is
  /// recorded and counted rather than dropped — and it takes two hundred plants
  /// to reach.
  factory Plant.forMilestone(
    Milestone milestone, {
    required String id,
    required DateTime plantedAt,
    GardenPlot? plot,
  }) =>
      Plant(
        id: id,
        sessionId: null,
        type: PlantType.bonus,
        species: milestone.species,
        // Awarded fully grown. A bonus plant is not watched growing — there is
        // no session under it to watch — so the only stage it could honestly be
        // in is the one it arrives in.
        stage: GrowthStage.mature,
        plantedAt: plantedAt,
        sessionDuration: null,
        milestone: milestone,
        plot: plot,
      );

  final String id;

  /// The session that grew this plant. Nullable because ticket 13's milestone
  /// plants are earned by a count of sessions rather than by any one of them.
  final String? sessionId;

  final PlantType type;
  final PlantSpecies species;

  /// How grown this plant is. Always [GrowthStage.mature] for a plant a session
  /// earned — a plant only reaches the garden by completing — and stored rather
  /// than assumed so the column means what it says.
  final GrowthStage stage;

  /// When the seed went in: the session's anchor.
  final DateTime plantedAt;

  /// The planned duration of the session that grew this. What ticket 12's card
  /// shows, and the reason this plant is the type it is.
  ///
  /// Null for a bonus plant, which no session grew. Nullable rather than zero
  /// because "no session" and "a session of no length" are different claims,
  /// and a card reading the second one would say **0 minutes** about an award
  /// for a thousand of them.
  final Duration? sessionDuration;

  /// The milestone that awarded this plant, or null if a session grew it.
  ///
  /// The whole of what makes a plant a bonus plant — see [isBonus]. There is no
  /// separate flag beside it, deliberately: PRD §4.3 carries both an
  /// `isBonusPlant` boolean and a `milestoneSessions` integer, and two columns
  /// that can disagree about the same fact are one column too many. A plant has
  /// a milestone or it does not.
  final Milestone? milestone;

  /// Whether a milestone awarded this plant rather than a session growing it.
  ///
  /// What every count of "sessions" has to exclude: a bonus plant is not a
  /// session anybody sat through, and a statistic that counted it would be
  /// telling the user they had done work they had not.
  bool get isBonus => milestone != null;

  /// Where in the garden this plant stands.
  ///
  /// Stored rather than recomputed on the way out of the database, which is
  /// what makes the garden look the same on every launch: the plot is decided
  /// once, when the plant is sown, against the garden as it was at that moment.
  /// Recomputing it would re-lay the whole garden the first time a plant was
  /// deleted or a rule was changed, and the user would open a garden they did
  /// not recognise.
  ///
  /// Null for a plant the garden has no room for — the two-hundred-and-first —
  /// which is kept and counted rather than dropped. See ADR 0006.
  final GardenPlot? plot;

  /// This plant, moved to [plot].
  ///
  /// Here for the migration that gave the existing gardens their plots, and for
  /// ticket 20's decor, which will have to shuffle a plant out of a plot the
  /// user wants a bench in.
  Plant inPlot(GardenPlot? plot) => Plant(
        id: id,
        sessionId: sessionId,
        type: type,
        species: species,
        stage: stage,
        plantedAt: plantedAt,
        sessionDuration: sessionDuration,
        milestone: milestone,
        plot: plot,
      );

  /// Plants compare by value: two reads of the same row are the same plant.
  @override
  bool operator ==(Object other) =>
      other is Plant &&
      other.id == id &&
      other.sessionId == sessionId &&
      other.type == type &&
      other.species == species &&
      other.stage == stage &&
      other.plantedAt == plantedAt &&
      other.sessionDuration == sessionDuration &&
      other.milestone == milestone &&
      other.plot == plot;

  @override
  int get hashCode => Object.hash(
        id,
        sessionId,
        type,
        species,
        stage,
        plantedAt,
        sessionDuration,
        milestone,
        plot,
      );

  @override
  String toString() =>
      'Plant($id, ${species.name}, planted $plantedAt, '
      '${milestone == null ? sessionDuration : milestone!.label}, '
      '${plot ?? 'no plot'})';
}
