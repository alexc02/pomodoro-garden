import '../garden/garden_plot.dart';
import '../garden/plant.dart';
import 'calendar_day.dart';
import 'day_range.dart';
import 'streak.dart';

/// Completed session count plus total focus time over some span.
///
/// [focus] is the sum of planned durations, which equals time focused since a
/// session only completes at its planned duration. Paused time isn't included.
final class SessionTally {
  const SessionTally({required this.sessions, required this.focus});

  static const SessionTally none =
      SessionTally(sessions: 0, focus: Duration.zero);

  final int sessions;

  final Duration focus;

  @override
  bool operator ==(Object other) =>
      other is SessionTally &&
      other.sessions == sessions &&
      other.focus == focus;

  @override
  int get hashCode => Object.hash(sessions, focus);

  @override
  String toString() => 'SessionTally($sessions sessions, $focus)';
}

/// Plants in the garden, and how many of them were milestone awards.
final class PlantTally {
  const PlantTally({required this.plants, required this.bonusPlants});

  static const PlantTally none = PlantTally(plants: 0, bonusPlants: 0);

  /// Every plant recorded, awards included.
  final int plants;

  /// How many of [plants] carry a milestone.
  final int bonusPlants;

  @override
  bool operator ==(Object other) =>
      other is PlantTally &&
      other.plants == plants &&
      other.bonusPlants == bonusPlants;

  @override
  int get hashCode => Object.hash(plants, bonusPlants);

  @override
  String toString() => 'PlantTally($plants plants, $bonusPlants awarded)';
}

/// This week's summary.
final class JournalWeek {
  const JournalWeek._({
    required this.range,
    required this.sessions,
    required this.focus,
    required this.plants,
  });

  /// Award plants are dropped here rather than in the query so the rule
  /// stays in the domain.
  factory JournalWeek.of({
    required DayRange week,
    required SessionTally sessions,
    required List<Plant> plants,
  }) {
    return JournalWeek._(
      range: week,
      sessions: sessions.sessions,
      focus: sessions.focus,
      plants: List.unmodifiable(plants.where((plant) => !plant.isBonus)),
    );
  }

  final DayRange range;

  final int sessions;

  final Duration focus;

  /// Non-award plants, in query order. The card draws them.
  final List<Plant> plants;

  int get plantsGrown => plants.length;
}

/// The month as sessions per day (heatmap).
final class JournalMonth {
  const JournalMonth._({
    required this.range,
    required Map<CalendarDay, int> byDay,
  }) : _sessionsByDay = byDay;

  /// [sessionsByDay] only needs the days that had sessions.
  factory JournalMonth.of({
    required DayRange month,
    required Map<CalendarDay, int> sessionsByDay,
  }) =>
      JournalMonth._(range: month, byDay: Map.unmodifiable(sessionsByDay));

  final DayRange range;

  final Map<CalendarDay, int> _sessionsByDay;

  /// Zero for empty days and days outside the month.
  int sessionsOn(CalendarDay day) => _sessionsByDay[day] ?? 0;

  /// Max sessions on any one day. Shading is scaled against this.
  int get busiestDay => _sessionsByDay.values
      .fold(0, (most, count) => count > most ? count : most);

  int get sessions => _sessionsByDay.values.fold(0, (total, n) => total + n);

  int get daysTended => _sessionsByDay.length;
}

/// Lifetime totals.
final class JournalLifetime {
  const JournalLifetime._({
    required this.sessions,
    required this.focus,
    required this.plants,
    required this.bonusPlants,
  });

  factory JournalLifetime.of({
    required SessionTally sessions,
    required PlantTally plants,
  }) =>
      JournalLifetime._(
        sessions: sessions.sessions,
        focus: sessions.focus,
        plants: plants.plants,
        bonusPlants: plants.bonusPlants,
      );

  final int sessions;

  final Duration focus;

  /// Awards included.
  final int plants;

  final int bonusPlants;

  int get gardenLevel => GardenPlots.levelAfter(sessions);

  int get plots => GardenPlots.unlockedAfter(sessions);
}

/// The journal page: week, month and lifetime cards plus the streak.
///
/// Everything is derived from the session and plant tables, no stored
/// counters, so it stays in sync after a restore or reset.
final class Journal {
  const Journal({
    required this.today,
    required this.week,
    required this.month,
    required this.lifetime,
    required this.streak,
    this.firstTended,
  });

  /// The day every range here is relative to.
  final CalendarDay today;

  final JournalWeek week;

  final JournalMonth month;

  final JournalLifetime lifetime;

  final Streak streak;

  /// Earliest day with a completed session, or null. Limits how far back the
  /// heatmap can page.
  final CalendarDay? firstTended;

  /// Nothing recorded yet (fresh install).
  bool get isEmpty => lifetime.sessions == 0 && lifetime.plants == 0;
}
