import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../analytics/analytics_providers.dart';
import '../data/database_providers.dart';
import '../journal/journal_providers.dart';
import '../session/session_providers.dart';
import '../time/clock_provider.dart';
import 'decor_providers.dart';
import 'plant_providers.dart';

/// Bonus plants awarded but not yet celebrated.
///
/// The state is just the queue; the plants table is what records an award.
/// Session count and already-awarded milestones both come from the database,
/// so nothing here can drift.
final milestoneAwardsProvider =
    NotifierProvider<MilestoneAwards, List<Plant>>(MilestoneAwards.new);

/// Hands out earned bonus plants, exactly once each.
///
/// [catchUp] awards every milestone the total has reached that isn't already
/// planted (see [Milestone.dueFrom]), so an existing user gets their backlog
/// and running it twice is harmless. Runs at launch and after every
/// completion. Calls are serialised so two runs can't both plant the same
/// milestone; the unique index on `plants.milestone_sessions` is the backstop.
class MilestoneAwards extends Notifier<List<Plant>> {
  Future<void> _inFlight = Future<void>.value();

  @override
  List<Plant> build() {
    // Fires after the session row is written, so the new count is real.
    ref.listen(completedSessionsProvider, (_, next) {
      if (next.hasValue) unawaited(catchUp());
    });

    // Plus once at launch for users who already have sessions.
    unawaited(catchUp());

    return const [];
  }

  /// Awards everything due. Idempotent; calls queue rather than race.
  Future<void> catchUp() {
    _inFlight = _inFlight.then((_) => _award());
    return _inFlight;
  }

  /// Drops [plant] from the queue once it's been shown. The plant itself stays
  /// in the garden even if the card was dismissed or the app was killed.
  void celebrated(Plant plant) {
    state = List.unmodifiable(
      state.where((queued) => queued.id != plant.id),
    );
  }

  Future<void> _award() async {
    try {
      final garden = ref.read(plantRepositoryProvider);
      final completed = await ref.read(completedSessionsProvider.future);
      if (!ref.mounted) return;

      final due = Milestone.dueFrom(
        completedSessions: completed.length,
        awarded: await garden.awardedMilestones(),
      );
      if (due.isEmpty || !ref.mounted) return;

      final ids = ref.read(idSourceProvider);
      final at = ref.read(clockProvider).now();
      final arrangement = ref.read(decorRepositoryProvider);
      // Kept up to date as awards go in, so a backlog doesn't give two
      // plants the same plot.
      final occupied = await garden.occupiedPlots();
      final arranged = await arrangement.occupiedPlots();
      var displacedAny = false;

      final awarded = <Plant>[];
      try {
        for (final milestone in due) {
          // Same placement rule as a session's plant: decor gets stepped
          // over and only displaced when the garden is completely full. Not
          // limited by unlocked plots; `GardenLayout` grows to fit. A null
          // plot means 200 plants; the plant is still recorded.
          final sowing = GardenPlots.sow(plants: occupied, decor: arranged);
          final plot = sowing.plot;
          if (plot != null) occupied.add(plot);

          final displaced = sowing.displacing;
          if (displaced != null) {
            await arrangement.removeIn(displaced);
            arranged.remove(displaced);
            displacedAny = true;
          }

          final plant = Plant.forMilestone(
            milestone,
            id: ids.newId(),
            // Award time; no single session earned it.
            plantedAt: at,
            plot: plot,
          );
          await garden.save(plant);
          // `plant_grown`, same as a session's plant.
          ref.read(analyticsProvider).record(
                PlantGrown(species: plant.species, stageReached: plant.stage),
              );
          awarded.add(plant);
        }
      } finally {
        // Refresh decor even if a later award threw, so the garden doesn't
        // draw an item that's gone from the table.
        if (displacedAny && ref.mounted) ref.invalidate(decorProvider);
        // Publish whatever landed, even if a later award threw.
        if (awarded.isNotEmpty && ref.mounted) {
          ref.invalidate(plantsProvider);
          // The journal's lifetime card counts awards too.
          ref.invalidate(journalProvider);
          ref.invalidate(journalMonthProvider);
          state = List.unmodifiable([...state, ...awarded]);
        }
      }
    } catch (error, stack) {
      // Report, don't rethrow. The next catch-up will retry.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription('awarding milestone plants'),
      ));
    }
  }
}
