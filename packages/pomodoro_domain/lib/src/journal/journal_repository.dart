import '../garden/plant.dart';
import 'calendar_day.dart';
import 'day_range.dart';
import 'journal.dart';

/// Where the journal's figures are counted.
///
/// A port like [SessionRepository] and [PlantRepository], and the odd one of
/// the three: it writes nothing and it returns no sessions. Every method here
/// is an **aggregate** — a count, a sum, or one row per day — because the
/// journal's job is to summarise a history that grows without limit, and a
/// summary computed by loading that history into memory is one that gets slower
/// every month the user keeps using the app.
///
/// That is the requirement rather than an implementation note, so it is stated
/// here where an implementation has to read it: *no method on this interface
/// may be implemented by reading the rows and folding them in Dart.* The one
/// exception is [plantsIn], which returns objects rather than a number, and is
/// bounded by a week.
///
/// **Which day a session belongs to.** Every method that groups or filters by
/// day uses the local day a session was *anchored* in — the evening the user
/// remembers working, not the small hours they finished in. See
/// `docs/adr/0012-a-day-in-the-journal-is-the-day-a-session-was-anchored.md`,
/// and [CalendarDay] for why the day is a date and not a span of hours.
abstract interface class JournalRepository {
  /// How many sessions were completed in [range], and how long they came to.
  Future<SessionTally> sessionsIn(DayRange range);

  /// The same, over every session ever completed.
  Future<SessionTally> sessionsEver();

  /// How many sessions were completed on each day of [range].
  ///
  /// Only the days with something in them are in the map: a day with no entry
  /// had no completed session, which is what the heatmap draws as bare soil.
  Future<Map<CalendarDay, int>> sessionsByDay(DayRange range);

  /// Every day with at least one completed session in it, most recent first.
  ///
  /// One row per day rather than per session — this is what a streak is
  /// counted from, and a user with four years behind them has at most fourteen
  /// hundred of these however many thousand sessions they did.
  Future<List<CalendarDay>> daysWithSessions();

  /// The plants planted in [range], most recent first.
  ///
  /// Bounded by the range the journal asks for — a week — because these are
  /// the plants the weekly card draws rather than counts. Awards are included;
  /// [JournalWeek.of] is where they are dropped.
  Future<List<Plant>> plantsIn(DayRange range);

  /// How many plants are in the garden, and how many were awarded.
  Future<PlantTally> plantsEver();
}
