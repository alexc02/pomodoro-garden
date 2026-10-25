import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../analytics/analytics_providers.dart';
import '../data/database_providers.dart';
import '../journal/journal_providers.dart';
import '../session/session_providers.dart';
import 'decor_providers.dart';
import 'milestone_providers.dart';
import 'plant_providers.dart';

/// REQ-036's reset: whether it may be done right now, what it is doing, and the
/// one thing that does it.
///
/// The clearing itself is `DriftGardenReset`, behind the `GardenReset` port.
/// What is here is everything *around* the four deletes — the refusal while a
/// timer is in flight, and the republishing that makes the empty garden arrive
/// on screen rather than at the next launch.

/// Whether a reset is being done right now.
///
/// Two states, and deliberately not four: how a reset *ended* is a
/// [ResetOutcome] handed back to whoever asked for it, not a state left lying
/// about afterwards for a screen to notice. See [GardenResetController.clear]
/// for why the difference matters here more than it does for an export.
enum Resetting {
  /// Nothing is being cleared, which is almost always.
  idle,

  /// The four deletes are in flight.
  clearing,
}

/// How a reset ended.
///
/// Returned rather than published, because the message about it is said once to
/// the person who asked. A state would outlive them — the settings tab is kept
/// alive by the shell's `IndexedStack`, so *your garden is empty* would still
/// be sitting there an hour and three sessions later, by which time it is not
/// true.
enum ResetOutcome {
  /// The four tables are empty and every surface has been told.
  cleared,

  /// A timer went into flight between the frame that drew the button and the
  /// second confirmation being answered. Nothing was touched.
  ///
  /// Not a failure and not something to apologise for. The section has already
  /// gone back to its held-back note, which says why.
  refused,

  /// The deletes did not go through, and the garden is exactly as it was.
  failed,
}

/// Whether REQ-036's reset may be done at all, right now.
///
/// **Nothing may be counting down, and nothing may be showing a session that
/// has just ended.** The ticket allows either refusing or cancelling the
/// session first, and this is the refusal: a reset that quietly abandoned a
/// session the user was thirty seconds from finishing would be a destructive
/// act they did not ask for, hidden behind two confirmations that were about
/// something else. The two taps in front of this one say *your plants and your
/// stats*; they do not say *and the session you are in the middle of*.
///
/// The four closed phases are written out exhaustively rather than derived, so
/// that a phase added by a later ticket is a compile error here and has to be
/// given an answer on this rule's own terms — which is *destroying*, and is not
/// the same question as any other screen's.
///
/// [SessionPhase.completed] is closed for the sharpest reason of the four: it
/// is the screen with the finished plant on it, and clearing the garden from
/// under that screen is exactly the stale data the ticket's last criterion is
/// about. [SessionPhase.breakOver] is open — nothing is counting down, and
/// nothing moves the timer out of it except starting the next session, so
/// leaving it shut would shut the door for the rest of the run.
///
/// Watched rather than checked at the tap, so the control is honest about
/// itself before it is pressed instead of doing nothing when it is.
final gardenMayBeResetProvider = Provider<bool>((ref) {
  return switch (ref.watch(sessionControllerProvider).phase) {
    SessionPhase.idle || SessionPhase.breakOver => true,
    SessionPhase.running ||
    SessionPhase.paused ||
    SessionPhase.completed ||
    SessionPhase.onBreak =>
      false,
  };
});

/// Clears the garden, and puts every surface that was showing it back to empty.
final gardenResetControllerProvider =
    NotifierProvider<GardenResetController, Resetting>(
  GardenResetController.new,
);

/// The one thing in the app that clears a garden.
///
/// **The deletes are the easy half.** What this class is actually for is the
/// second half of the ticket's last criterion: the journal is a set of
/// aggregate queries that were run once, the garden is a list of plants that
/// was read once, and the milestone queue is a list held in memory — none of
/// them watches the tables underneath, because nothing else in this app ever
/// empties one. So the reset tells them, and the telling is enumerated below
/// rather than left to a `ref.invalidate` at each call site, because a surface
/// that was forgotten here is a surface still showing a garden the user was
/// promised was gone.
///
/// **Nothing is recorded.** PRD §7.1's table has no `garden_reset` in it, and
/// [AnalyticsEventName] is kept to names that have a call site — but the
/// sharper reason is that the log is one of the four things being cleared, so
/// an event recorded here would be the single row in a log the user just
/// emptied, and the app's only remaining note of a garden they asked it to
/// forget.
class GardenResetController extends Notifier<Resetting> {
  @override
  Resetting build() => Resetting.idle;

  /// Clears the garden, and says how it went. The user has said yes twice by
  /// the time anything gets here — see `confirmGardenReset`, where both
  /// confirmations live.
  ///
  /// **The outcome is returned rather than published**, which is the one place
  /// this differs from `GardenExportController`. That one leaves its outcome in
  /// state for a screen to watch, and it is read by a screen the user has to be
  /// looking at. The reset's door is on a
  /// tab the shell keeps alive for the life of the app, so an outcome left in
  /// state would still be there hours later — and *your garden is empty* is a
  /// sentence that stops being true the first time a session finishes.
  /// Returning it means the message belongs to the tap, and the tap is over.
  ///
  /// Refuses if a timer is in flight. The screen watches
  /// [gardenMayBeResetProvider] and offers no button in that case, so this is
  /// the backstop under that rather than the place it is enforced. It is a real
  /// case rather than only a guard: a break can auto-start between the frame
  /// that
  /// drew the button and the second confirmation being answered.
  Future<ResetOutcome> clear() async {
    if (!ref.read(gardenMayBeResetProvider)) return ResetOutcome.refused;
    if (state == Resetting.clearing) return ResetOutcome.refused;
    state = Resetting.clearing;

    try {
      await ref.read(gardenResetProvider).clear();
    } catch (error, stack) {
      // Reported as well as returned. A reset that did not happen is worth
      // knowing about loudly, and it is not worth taking the running app down
      // for — the same judgement `SessionController._write` makes about a
      // failed write. What the user is told is the caller's business.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription('resetting the garden'),
      ));
      if (ref.mounted) state = Resetting.idle;
      return ResetOutcome.failed;
    }

    if (!ref.mounted) return ResetOutcome.cleared;
    _republish();
    state = Resetting.idle;
    return ResetOutcome.cleared;
  }

  /// Tells every surface that read the cleared tables to read them again.
  ///
  /// In dependency order, though Riverpod does not need it to be: the garden is
  /// built from the plants, the arrangement and the session count, and listing
  /// them in the order they are consumed is what makes it possible to check
  /// this list against the tables `DriftGardenReset` empties.
  void _republish() {
    // The plants table, as the garden and the journal's weekly card read it.
    ref.invalidate(plantsProvider);
    // REQ-040's arrangement, and the mode the user may have left open on the
    // garden tab — the shell keeps that tab alive in an `IndexedStack`, so an
    // arranging bar holding an item that no longer exists would still be there.
    ref.invalidate(decorProvider);
    ref.invalidate(decorArrangerProvider);
    // The sessions table. `gardenLayoutProvider` reads this for capacity, so
    // the garden comes back to its twelve plots off the back of this one line.
    ref.invalidate(completedSessionsProvider);
    // The journal's six aggregates, every week any locale asked for.
    ref.invalidate(journalProvider);
    ref.invalidate(journalMonthProvider);
    // REQ-021's queue. The awards themselves were rows in `plants` and are
    // already gone; this is the list of ones awarded but not yet celebrated,
    // which must not survive into a garden that has earned nothing. Rebuilding
    // it runs a catch-up against zero completed sessions, which is due nothing.
    ref.invalidate(milestoneAwardsProvider);
    // PRD §7.1's events, for the debug screen that shows them.
    ref.invalidate(recentEventsProvider);
    ref.read(sessionControllerProvider.notifier).resetCycle();
  }
}
