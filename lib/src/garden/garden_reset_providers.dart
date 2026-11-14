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

/// Controls around the garden reset. The deletes themselves are
/// `DriftGardenReset` (behind the `GardenReset` port); this handles refusing
/// while a timer is active and refreshing everything afterwards.

/// Whether a reset is in progress. How it ended is returned as a
/// [ResetOutcome], not left in state.
enum Resetting {
  idle,

  clearing,
}

/// How a reset ended. Returned rather than stored: the settings tab stays
/// alive in the shell's `IndexedStack`, so a stored "garden is empty" would
/// still be showing hours later when it's no longer true.
enum ResetOutcome {
  /// All four tables empty and every surface refreshed.
  cleared,

  /// A timer started between drawing the button and the second confirmation.
  /// Nothing was touched; the section already shows why.
  refused,

  /// The deletes failed; the garden is unchanged.
  failed,
}

/// Whether a reset is allowed right now.
///
/// We refuse rather than cancel an in-flight session, since the confirmations
/// don't mention losing the current session. [SessionPhase.completed] is
/// closed too (that screen shows the finished plant). [SessionPhase.breakOver]
/// stays open, otherwise nothing would reopen it until the next session.
/// Phases are listed exhaustively so a new one forces a decision here.
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

final gardenResetControllerProvider =
    NotifierProvider<GardenResetController, Resetting>(
  GardenResetController.new,
);

/// The only thing in the app that clears a garden.
///
/// The deletes are the easy bit. None of the journal, garden or milestone
/// queue watch their tables, so [_republish] lists every one explicitly.
///
/// Deliberately records no analytics event: the event log is one of the
/// tables being wiped.
class GardenResetController extends Notifier<Resetting> {
  @override
  Resetting build() => Resetting.idle;

  /// Clears the garden and returns how it went. Both confirmations happen
  /// earlier, in `confirmGardenReset`.
  ///
  /// Unlike `GardenExportController`, the outcome is returned, not kept in
  /// state (see [ResetOutcome]). The [gardenMayBeResetProvider] check is a
  /// backstop: a break can auto-start between the button being drawn and the
  /// second confirmation.
  Future<ResetOutcome> clear() async {
    if (!ref.read(gardenMayBeResetProvider)) return ResetOutcome.refused;
    if (state == Resetting.clearing) return ResetOutcome.refused;
    state = Resetting.clearing;

    try {
      await ref.read(gardenResetProvider).clear();
    } catch (error, stack) {
      // Report and return; don't take the app down.
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
  /// Ordered to match the tables `DriftGardenReset` empties, for easy checking.
  void _republish() {
    ref.invalidate(plantsProvider);
    // The arranger too: the garden tab stays alive, and an open arranging
    // bar could be holding an item that no longer exists.
    ref.invalidate(decorProvider);
    ref.invalidate(gardenArrangerProvider);
    // `gardenLayoutProvider` reads this for capacity, so this resets the
    // plot count back to twelve.
    ref.invalidate(completedSessionsProvider);
    ref.invalidate(journalProvider);
    ref.invalidate(journalMonthProvider);
    // Awarded-but-uncelebrated queue. Rebuilding runs a catch-up against
    // zero sessions, so nothing is due.
    ref.invalidate(milestoneAwardsProvider);
    // For the debug events screen.
    ref.invalidate(recentEventsProvider);
    ref.read(sessionControllerProvider.notifier).resetCycle();
  }
}
