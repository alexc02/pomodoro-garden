import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../session/session_providers.dart';
import 'decor_providers.dart';
import 'plant_providers.dart';

/// The garden as it stands: its plots, and what is in them.
///
/// All three halves are read from the database rather than held anywhere — the
/// plants and REQ-040's decor because that is what makes the garden the same on
/// every launch, and the count of completed sessions because REQ-018's unlocks
/// are *derived* from it. A user who arrives at this build with three hundred
/// sessions behind them gets the plots they earned on their first launch;
/// nothing counts up from twelve.
///
/// The underlying providers are invalidated by whatever changed the thing they
/// read — `SessionController` when a session completes, `DecorArranger` when the
/// user rearranges — so the garden gains its plant, its four new plots or its
/// bench without anything telling it to.
///
/// A garden is drawn from what is in it, which is a fact about the database and
/// about nothing else — with one exception that exists in debug builds alone,
/// [milestonePreviewProvider].
final gardenLayoutProvider = FutureProvider<GardenLayout>((ref) async {
  final plants = await ref.watch(plantsProvider.future);
  final decor = await ref.watch(decorProvider.future);
  final completed = await ref.watch(completedSessionsProvider.future);
  final preview = kDebugMode ? ref.watch(milestonePreviewProvider) : null;

  return GardenLayout.of(
    plants: preview == null
        ? plants
        : _withPreviewAwards(plants, decor, upTo: preview),
    decor: decor,
    completedSessions: completed.length,
  );
});

/// The top milestone a reviewer is previewing the garden at, or null for the
/// garden as it is (ticket 36).
///
/// REQ-021's two effects — the enchanted willow's halo and the golden garden's
/// shimmer — are earned at 500 and 1000 sessions, which nobody reviewing a build
/// is going to sit through. This lays those awards into the garden on screen
/// without writing anything: not a setting, never stored, and reachable only
/// from a control that exists in debug builds. Release builds compile the read
/// of it out.
final milestonePreviewProvider =
    NotifierProvider<MilestonePreview, Milestone?>(MilestonePreview.new);

/// Holds the milestone the debug affordance is previewing.
class MilestonePreview extends Notifier<Milestone?> {
  @override
  Milestone? build() => null;

  /// Previews the garden as though [milestone] (and the milestones it implies)
  /// had been reached, or stops previewing when [milestone] is null.
  void show(Milestone? milestone) => state = milestone;
}

/// [plants], with a stand-in award for each of the two effect-carrying
/// milestones up to [upTo] that the garden does not already hold, in the next
/// free plots.
List<Plant> _withPreviewAwards(
  List<Plant> plants,
  List<Decor> decor, {
  required Milestone upTo,
}) {
  final occupied = <GardenPlot>{
    for (final plant in plants) ?plant.plot,
    for (final item in decor) item.plot,
  };
  final held = {for (final plant in plants) plant.milestone};
  final previewed = [
    for (final milestone in [Milestone.fiveHundred, Milestone.oneThousand])
      if (milestone.sessions <= upTo.sessions && !held.contains(milestone))
        milestone,
  ];

  return [
    ...plants,
    for (final milestone in previewed)
      () {
        final plot = GardenPlots.nextFree(occupied);
        if (plot != null) occupied.add(plot);
        return Plant.forMilestone(
          milestone,
          id: 'preview-${milestone.sessions}',
          plantedAt: DateTime.utc(2026),
          plot: plot,
        );
      }(),
  ];
}
