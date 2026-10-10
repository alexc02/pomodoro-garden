import '../garden/garden_plot.dart';
import '../garden/plant.dart';
import 'calendar_day.dart';
import 'day_range.dart';
import 'streak.dart';

/// How many sessions were completed in some span of time, and how long they
/// came to.
///
/// The shape every count of work in the journal arrives in — one query
/// answers both halves at once, and they are never apart afterwards, because a
/// card
/// showing five sessions and someone else's two hours would be worse than
/// either alone.
///
/// [focus] is the sum of the *planned durations* of those sessions, which is
/// exactly the time the user sat through: a session is completed only when it
/// reaches its planned duration, so there is no third number hiding here. Time
/// spent paused is not focus and is not in it.
final class SessionTally {
  const SessionTally({required this.sessions, required this.focus});

  /// Nothing completed, in a span with nothing in it.
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

/// How many plants are in the garden, and how many of them were awarded.
///
/// The two are counted together and reported apart, which is REQ-021's "no part
/// of any count of work done" said in figures: [plants] is everything standing
/// in the garden, and [bonusPlants] is how much of that nobody sat through.
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

/// REQ-026: what the user did this week.
final class JournalWeek {
  const JournalWeek._({
    required this.range,
    required this.sessions,
    required this.focus,
    required this.plants,
  });

  /// The week [week] covers, as [sessions] and [plants] describe it.
  ///
  /// [plants] is every plant planted in the week; the awards among them are
  /// dropped here rather than by the query, so the rule about what counts as
  /// work done lives in the domain and not in a `WHERE` clause.
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

  /// The seven days this is a summary of.
  final DayRange range;

  /// How many sessions were completed in them.
  final int sessions;

  /// How long those sessions came to.
  final Duration focus;

  /// The plants they grew, in the order the query returned them.
  ///
  /// The plants themselves rather than a count of them, because the card draws
  /// them: REQ-026's row of small green things is the week's work, and a number
  /// beside a picture of it says the same thing twice.
  final List<Plant> plants;

  /// How many plants the week grew.
  int get plantsGrown => plants.length;
}

/// REQ-027: the month, as a count of sessions per day.
final class JournalMonth {
  const JournalMonth._({
    required this.range,
    required Map<CalendarDay, int> byDay,
  }) : _sessionsByDay = byDay;

  /// The month [month] covers, with [sessionsByDay] holding only the days that
  /// had something in them.
  factory JournalMonth.of({
    required DayRange month,
    required Map<CalendarDay, int> sessionsByDay,
  }) =>
      JournalMonth._(range: month, byDay: Map.unmodifiable(sessionsByDay));

  /// Every day the grid draws, empty ones included.
  final DayRange range;

  /// Only the days with at least one session in them. The absent days are the
  /// bare soil.
  final Map<CalendarDay, int> _sessionsByDay;

  /// How many sessions were completed on [day]. Zero for a day with none, and
  /// for a day outside the month.
  int sessionsOn(CalendarDay day) => _sessionsByDay[day] ?? 0;

  /// The most sessions any one day of the month holds.
  ///
  /// What the shading is scaled against, so that a month whose best day was
  /// three is drawn as fully as a month whose best day was twelve. The user is
  /// being shown the shape of their own month, not their rank against someone
  /// else's.
  int get busiestDay => _sessionsByDay.values
      .fold(0, (most, count) => count > most ? count : most);

  /// How many sessions the month came to.
  int get sessions => _sessionsByDay.values.fold(0, (total, n) => total + n);

  /// How many days of the month had at least one session in them.
  int get daysTended => _sessionsByDay.length;
}

/// REQ-028: the totals that only ever go up.
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

  /// Every session ever completed.
  final int sessions;

  /// Every hour of them.
  final Duration focus;

  /// Every plant in the garden, awards included.
  final int plants;

  /// How many of those were awarded rather than grown.
  final int bonusPlants;

  /// REQ-028's garden level, derived from [sessions] like everything else here.
  int get gardenLevel => GardenPlots.levelAfter(sessions);

  /// How many plots that level has opened — the same rule read the other way.
  int get plots => GardenPlots.unlockedAfter(sessions);
}

/// The botanical journal: one page, three cards, and the streak across them.
///
/// Every figure on it is derived from the two tables the app already keeps —
/// nothing here is a counter kept alongside the rows it counts, which is what
/// makes a journal opened after a restore, an export or a reset agree with the
/// garden next to it. See the ticket README's "derived counters" decision.
final class Journal {
  const Journal({
    required this.today,
    required this.week,
    required this.month,
    required this.lifetime,
    required this.streak,
    this.firstTended,
  });

  /// The day the journal was read on, and the day every range in it is
  /// relative to.
  final CalendarDay today;

  final JournalWeek week;

  final JournalMonth month;

  final JournalLifetime lifetime;

  /// REQ-029, kept beside the three cards rather than inside one: a streak is
  /// not a fact about this week, it is a fact about every day up to today.
  final Streak streak;

  /// The earliest day with a completed session on it, or null when there is
  /// none. How far back REQ-027's heatmap can be stepped: before this month
  /// there is nothing to show but soil.
  final CalendarDay? firstTended;

  /// Whether this user has nothing recorded at all.
  ///
  /// What the screen asks before drawing three cards of zeroes at somebody who
  /// has just installed the app.
  bool get isEmpty => lifetime.sessions == 0 && lifetime.plants == 0;
}
