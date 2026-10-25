import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'database.dart';

/// [GardenReset] over SQLite: REQ-036's reset as four deletes in one
/// transaction.
///
/// **The transaction is the whole of this class.** Every one of the four tables
/// is a `DELETE FROM` with no `WHERE` — there is nothing here to get wrong
/// about a row — and what would go wrong without the transaction is the state
/// *between* two of them. A reset that cleared the plants and then failed would
/// leave the sessions behind, and the app that opened next would derive forty
/// plots of capacity for an empty garden and decide that seven milestones were
/// owed to somebody who had just asked to start again. See [GardenReset], where
/// that reasoning is written down for the port rather than for the SQLite
/// behind it.
///
/// **The table that is not listed here is the point of the ticket.** `settings`
/// is in the same file and is not touched: what the user chose is not part of a
/// garden. That it is absent by *omission* is the one thing about this class
/// worth a second look, so it is said here rather than left to be noticed — a
/// fifth line added below in some later ticket would clear the user's session
/// length, and nothing but this paragraph would stop it.
final class DriftGardenReset implements GardenReset {
  const DriftGardenReset(this._database);

  final AppDatabase _database;

  @override
  Future<void> clear() {
    return _database.transaction(() async {
      // The plants before the sessions, though nothing enforces the order:
      // `plants.session_id` is not a foreign key — see [Plants.sessionId],
      // which says why — so this is only the order somebody reading it would
      // expect, and a reader is what the order is for.
      await _database.delete(_database.plants).go();
      await _database.delete(_database.sessions).go();
      // REQ-040's arrangement. Cleared with the rest, and this is the one entry
      // in the list that had a choice about it: an arrangement is something the
      // user composed, and losing it is a real loss. It goes because a bench
      // holds its plot open in `GardenLayout` — so an arrangement that survived
      // would leave the "fresh start" showing forty plots of bare soil with
      // four ornaments in it, which is not the twelve-plot garden the second
      // confirmation promised. Nothing stops the user arranging again.
      await _database.delete(_database.gardenDecor).go();
      // PRD §7.1's events, which `AnalyticsEventLog.clear` already said would
      // go this way: the log is the one place the app would still remember a
      // garden the user asked it to forget.
      await _database.delete(_database.analyticsEvents).go();
      await _database.customStatement('DELETE FROM cycle');
    });
  }
}
