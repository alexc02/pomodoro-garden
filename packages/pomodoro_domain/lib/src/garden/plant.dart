import '../session/focus_session.dart';
import 'garden_plot.dart';
import 'growth_stage.dart';
import 'milestone.dart';
import 'plant_type.dart';

/// What a running session is growing right now. Derived, never stored.
///
/// Species comes from the session id so it can't change mid-session.
final class PlantGrowth {
  const PlantGrowth({
    required this.type,
    required this.species,
    required this.stage,
    required this.sessionId,
  });

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

  final PlantType type;

  final PlantSpecies species;

  final GrowthStage stage;

  /// Also the seed for per-plant variation (e.g. sway offset).
  final String sessionId;

  /// Value equality so ticks that don't change the stage don't repaint.
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

/// A plant in the garden, left by one completed session or a milestone.
///
/// Type, species and stage are stored rather than re-derived, so changing the
/// growth rules doesn't rewrite existing gardens.
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

  /// Throws [ArgumentError] if the session didn't complete. [plot] comes from
  /// [GardenPlots.nextFree]; null means the garden is full.
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
      // Planted at the start, so a session crossing midnight belongs to the
      // evening it started in.
      plantedAt: session.startedAt,
      sessionDuration: session.plannedDuration,
      plot: plot,
    );
  }

  /// A bonus plant for [milestone]. No session, so no [sessionId] or
  /// [sessionDuration]. [plantedAt] is when it was awarded. Null [plot] means
  /// a full garden.
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
        // No session to watch it grow, so it arrives mature.
        stage: GrowthStage.mature,
        plantedAt: plantedAt,
        sessionDuration: null,
        milestone: milestone,
        plot: plot,
      );

  final String id;

  /// Null for milestone plants.
  final String? sessionId;

  final PlantType type;
  final PlantSpecies species;

  /// Always [GrowthStage.mature] for session plants; stored anyway.
  final GrowthStage stage;

  /// The session's start time.
  final DateTime plantedAt;

  /// Planned duration of the session. Null for bonus plants (not zero: the card
  /// would show "0 minutes").
  final Duration? sessionDuration;

  /// Null if a session grew it. This is the only bonus flag; see [isBonus].
  final Milestone? milestone;

  /// Bonus plants are excluded from any count of work done.
  bool get isBonus => milestone != null;

  /// Stored, not recomputed, so the layout is stable across launches and rule
  /// changes. Null when the garden has no room left.
  final GardenPlot? plot;

  /// Used by the plot migration and when decor displaces a plant.
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
