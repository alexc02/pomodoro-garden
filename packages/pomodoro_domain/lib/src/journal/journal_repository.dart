import '../garden/plant.dart';
import 'calendar_day.dart';
import 'day_range.dart';
import 'journal.dart';

/// Read-only aggregate queries for the journal.
///
/// Implement these in the query (counts, sums, one row per day), not by
/// loading rows and folding them in Dart: history grows forever. [plantsIn] is
/// the exception and it's bounded by a week.
///
/// Days are the local day a session was anchored in, not the day it
/// finished.
abstract interface class JournalRepository {
  /// How many sessions were completed in [range], and how long they came to.
  Future<SessionTally> sessionsIn(DayRange range);

  /// The same, over every session ever completed.
  Future<SessionTally> sessionsEver();

  /// Completed sessions per day of [range]. Days with none are left out.
  Future<Map<CalendarDay, int>> sessionsByDay(DayRange range);

  /// Days with at least one completed session, most recent first. Used for
  /// streaks.
  Future<List<CalendarDay>> daysWithSessions();

  /// Plants planted in [range], most recent first. Includes awards;
  /// [JournalWeek.of] filters them out.
  Future<List<Plant>> plantsIn(DayRange range);

  /// How many plants are in the garden, and how many were awarded.
  Future<PlantTally> plantsEver();
}
