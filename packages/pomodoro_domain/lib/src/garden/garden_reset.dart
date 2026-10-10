/// REQ-036's reset: everything the app remembers about a garden, forgotten in
/// one go.
///
/// **A port of its own rather than a `clear` on each repository, and the reason
/// is that a half-cleared garden is worse than an uncleared one.** The plants,
/// the sessions behind them and the arrangement over them are three tables that
/// answer questions about each other: capacity is derived from the sessions,
/// the milestones already awarded are read off the plants, and the plot a bench
/// is standing in is what keeps that plot in the garden. Clear two of the three
/// and the app is not in a state any user could have reached — a garden of forty
/// plots with nothing in it, or a milestone the count says is owed and the
/// garden says was already given. Four repositories cleared in turn is four
/// chances to stop between them; one method is a transaction, and a transaction
/// is the only shape in which "reset" is a thing that either happened or did
/// not.
///
/// **What it does not reach is as much of the requirement as what it does.**
/// There is no method here that touches the settings row: a user asking for a
/// fresh garden has not asked for their session length back at twenty-five
/// minutes. It lives in a table this port has no business in.
abstract interface class GardenReset {
  /// Empties the plants, the sessions, the arrangement and the event log, all
  /// or nothing.
  ///
  /// Idempotent: a reset of an already-empty garden is four deletes that match
  /// no rows, which is what makes a second tap harmless rather than something
  /// the caller has to guard against.
  ///
  /// What is *not* cleared is everything derived from those four — capacity, the
  /// streak, the milestones owed, the garden level — because none of them is
  /// stored. They come back at their first-run values because the rows they are
  /// counted from are gone, which is the whole reason PRD §4.3's derived
  /// counters are derived.
  Future<void> clear();
}
