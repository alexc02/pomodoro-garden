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

/// REQ-021's awarding: which bonus plants the user has earned, and the ones
/// they have been given but not yet shown.
///
/// The state is the *queue*, not the awards — a plant leaves it when
/// `MilestoneKeeper` has celebrated it, and the garden is what remembers that
/// it was awarded at all. Nothing here counts anything: the number of completed
/// sessions comes from the sessions table and the list of milestones already
/// handed out comes from the plants table, so the two cannot drift apart from
/// each other or from what the user can see.
final milestoneAwardsProvider =
    NotifierProvider<MilestoneAwards, List<Plant>>(MilestoneAwards.new);

/// Hands out the bonus plants a user has earned, exactly once each.
///
/// Three decisions hold this together:
///
/// **Awarding is a catch-up, not a crossing.** [catchUp] asks which milestones
/// the *total* count has reached and which of those are not already in the
/// ground — see [Milestone.dueFrom] — so a user arriving at this build with
/// thirty sessions behind them collects the ten and the twenty-five rather than
/// nothing, and a check that runs twice hands out nothing the second time.
/// Nothing fires at a threshold, for the same reason nothing in this app fires
/// at the end of a session: the app is not running when the number goes past.
///
/// **It runs at launch and after every completion.** [build] does the first and
/// listens for the second, which between them are every moment the count can
/// have moved.
///
/// **Two awards never overlap.** Every call queues behind the last one, because
/// two runs reading the same "nothing awarded yet" would both try to plant the
/// same milestone. The unique index on `plants.milestone_sessions` is the
/// backstop under that, and it is the one that survives a bug here.
class MilestoneAwards extends Notifier<List<Plant>> {
  /// The awarding in flight, and the thing every later one waits on.
  Future<void> _inFlight = Future<void>.value();

  @override
  List<Plant> build() {
    // Every completion invalidates this, so it changing is the app noticing
    // that the count has moved. Listening to the count rather than to the timer
    // is deliberate: it fires *after* the session row has been written, which
    // is the only moment at which the new total is true.
    ref.listen(completedSessionsProvider, (_, next) {
      if (next.hasValue) unawaited(catchUp());
    });

    // And once at launch, because a listener fires on a change and a launch is
    // not one. This is the half of the requirement about the user who already
    // has thirty sessions: without it they would wait for their thirty-first.
    unawaited(catchUp());

    return const [];
  }

  /// Awards every milestone the user has reached and not yet been given.
  ///
  /// Safe to call at any time and any number of times: it is idempotent by
  /// construction, and calls queue rather than race.
  Future<void> catchUp() {
    _inFlight = _inFlight.then((_) => _award());
    return _inFlight;
  }

  /// Drops [plant] from the queue: the user has been shown it.
  ///
  /// Only the queue is emptied. The award itself is the row in the garden, so
  /// a celebration the user dismissed — or one the app was killed in the middle
  /// of — costs them the animation and not the plant.
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
      // Read once and kept up to date as the awards go in, because a backlog
      // plants several in a row and the second must not be handed the plot the
      // first has just taken — or the plot the first has just cleared an object
      // out of.
      final occupied = await garden.occupiedPlots();
      final arranged = await arrangement.occupiedPlots();
      var displacedAny = false;

      final awarded = <Plant>[];
      try {
        for (final milestone in due) {
          // The nearest free plot, exactly as a session's plant gets, and by
          // exactly the same rule — including REQ-040's: an object is stepped
          // over, and gives way only in a garden with nowhere left at all. An
          // award is a plant, so nothing about it is a weaker claim on a plot
          // than a session's plant has.
          //
          // Note what this is *not* asked about: how many plots the unlock
          // schedule has opened. The placement order runs past the schedule,
          // and `GardenLayout` grows the garden to hold whatever is planted in
          // it, so an award into a garden whose unlocked plots are all full
          // expands the garden rather than being turned away.
          //
          // Null is the only case that does not expand: two hundred plants,
          // where ADR 0006 already says what happens — the plant is recorded
          // and counted, and the garden says it is holding it. Not lost.
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
            // The instant of the award, not the anchor of the session that
            // earned it: no one session did.
            plantedAt: at,
            plot: plot,
          );
          await garden.save(plant);
          // §7.1's `plant_grown`, for the same reason a session's plant records
          // one: something new is standing in the garden. That no session grew
          // this one is the card's business and the journal's, not this event's.
          ref.read(analyticsProvider).record(
                PlantGrown(species: plant.species, stageReached: plant.stage),
              );
          awarded.add(plant);
        }
      } finally {
        // An arrangement that lost something is republished on its own, and
        // before the guard below: an award that threw after displacing an
        // object must not leave the garden drawing a bench that is no longer
        // in the table.
        if (displacedAny && ref.mounted) ref.invalidate(decorProvider);
        // Whatever landed is published, even if a later award threw. An award
        // that is in the garden but not in the queue is a plant the user finds
        // rather than one they are shown, which is a far smaller loss than one
        // they are shown and do not have.
        if (awarded.isNotEmpty && ref.mounted) {
          ref.invalidate(plantsProvider);
          // REQ-028's lifetime card counts the plants table, awards included,
          // so a bonus plant landing changes a figure on the journal as surely
          // as it changes the garden.
          ref.invalidate(journalProvider);
          ref.invalidate(journalMonthProvider);
          state = List.unmodifiable([...state, ...awarded]);
        }
      }
    } catch (error, stack) {
      // Reported rather than rethrown, on the same reasoning `SessionController`
      // swallows a failed write: an award that could not be made is worth
      // knowing about loudly, and is not worth taking the running app down for.
      // The next catch-up will try again, because nothing about the decision is
      // remembered anywhere but the garden.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pomodoro_garden',
        context: ErrorDescription('awarding milestone plants'),
      ));
    }
  }
}
