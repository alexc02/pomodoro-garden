import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../session/session_providers.dart';
import 'decor_providers.dart';
import 'plant_providers.dart';

/// The garden as it stands: plots, plants and decor.
///
/// Everything comes from the database; unlocked plots are derived from the
/// completed-session count, so an existing user gets the plots they've earned
/// straight away. The only non-database input is the debug-only
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

/// Debug only: preview the garden as if a milestone had been reached, so the
/// 500 halo and 1000 shimmer can be checked without grinding sessions. Never
/// stored; release builds compile the read out.
final milestonePreviewProvider =
    NotifierProvider<MilestonePreview, Milestone?>(MilestonePreview.new);

class MilestonePreview extends Notifier<Milestone?> {
  @override
  Milestone? build() => null;

  /// Preview up to [milestone], or stop previewing when null.
  void show(Milestone? milestone) => state = milestone;
}

/// [plants] plus stand-in 500/1000 awards (up to [upTo]) that aren't already
/// held, placed in the next free plots.
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
