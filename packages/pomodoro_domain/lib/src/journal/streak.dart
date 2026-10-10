import 'calendar_day.dart';

/// How many days in a row the user has finished at least one session: REQ-029.
///
/// A count of *days*, derived from the days that have a completed session in
/// them and from today — never a stored number that goes up and gets reset.
/// Nothing writes a streak down, so nothing can be owed one, and a user
/// arriving at this build with a fortnight behind them has a fortnight.
///
/// Two rules make it a gentle number rather than a scolding one:
///
/// **A day that is not over is not a day that was missed.** A user who has done
/// nothing yet today still has yesterday's streak, all of it, until midnight.
/// The alternative would be an app that resets a fortnight at 00:01 and asks
/// for a session before breakfast.
///
/// **A break is a rest, and it is counted rather than judged.** [restedDays] is
/// how long it has been, and it is the only thing this type says about a gap.
/// There is no "longest streak" to have fallen short of and no record to have
/// lost — see the screen, where the number becomes "your garden rested for
/// two days" and nothing more.
final class Streak {
  const Streak._({
    required this.days,
    required this.restedDays,
    required this.hasEverGrown,
  });

  /// The streak of a user who has never finished a session.
  static const Streak none =
      Streak._(days: 0, restedDays: 0, hasEverGrown: false);

  /// The streak [activeDays] amounts to, read on [today].
  ///
  /// [activeDays] is every day with at least one completed session in it, in
  /// any order and with repeats allowed: it comes from a grouped query, and
  /// what it means is "these days had something in them".
  factory Streak.from({
    required Iterable<CalendarDay> activeDays,
    required CalendarDay today,
  }) {
    // Days in the future are dropped rather than trusted. A device whose clock
    // was wrong and has been corrected can leave one behind, and a session
    // dated tomorrow must not hand out a streak that has not been earned.
    final days = activeDays.where((day) => !day.isAfter(today)).toSet();
    if (days.isEmpty) return none;

    final last = days.reduce((a, b) => a.isAfter(b) ? a : b);
    final rested = last.daysUntil(today);

    // Only today and yesterday keep a streak alive; anything older has a whole
    // empty day between it and now.
    if (rested > 1) {
      return Streak._(days: 0, restedDays: rested, hasEverGrown: true);
    }

    var run = 0;
    for (var day = last; days.contains(day); day = day.yesterday) {
      run++;
    }

    return Streak._(days: run, restedDays: rested, hasEverGrown: true);
  }

  /// How many days in a row, counting back from the most recent one with a
  /// session in it. Zero once a whole day has gone by without one.
  final int days;

  /// How many days it has been since the last completed session: 0 if there was
  /// one today, 1 if the last was yesterday.
  ///
  /// Zero for a user who has never finished one — there is nothing to have
  /// rested from, and [hasEverGrown] is how that case is told apart.
  final int restedDays;

  /// Whether there has ever been a completed session at all.
  final bool hasEverGrown;

  /// Whether the streak is standing.
  bool get isGrowing => days > 0;

  /// Whether the garden has been left to itself for a whole day or more.
  ///
  /// Never true for a user who has not started: a brand-new garden is not a
  /// neglected one, and the screen has something else to say to them.
  bool get isResting => restedDays > 1;

  @override
  bool operator ==(Object other) =>
      other is Streak &&
      other.days == days &&
      other.restedDays == restedDays &&
      other.hasEverGrown == hasEverGrown;

  @override
  int get hashCode => Object.hash(days, restedDays, hasEverGrown);

  @override
  String toString() => 'Streak($days days, rested $restedDays)';
}
