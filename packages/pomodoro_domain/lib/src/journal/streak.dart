import 'calendar_day.dart';

/// Consecutive days with at least one completed session.
///
/// Derived from the active days and today, never stored. Today doesn't break
/// the streak until it's over, and a gap is only reported as [restedDays]
/// (no "longest streak").
final class Streak {
  const Streak._({
    required this.days,
    required this.restedDays,
    required this.hasEverGrown,
  });

  static const Streak none =
      Streak._(days: 0, restedDays: 0, hasEverGrown: false);

  /// [activeDays] can be in any order and contain repeats.
  factory Streak.from({
    required Iterable<CalendarDay> activeDays,
    required CalendarDay today,
  }) {
    // Drop future days, e.g. left over from a clock that was wrong.
    final days = activeDays.where((day) => !day.isAfter(today)).toSet();
    if (days.isEmpty) return none;

    final last = days.reduce((a, b) => a.isAfter(b) ? a : b);
    final rested = last.daysUntil(today);

    // Only today or yesterday keeps the streak alive.
    if (rested > 1) {
      return Streak._(days: 0, restedDays: rested, hasEverGrown: true);
    }

    var run = 0;
    for (var day = last; days.contains(day); day = day.yesterday) {
      run++;
    }

    return Streak._(days: run, restedDays: rested, hasEverGrown: true);
  }

  /// Zero once a whole day has passed without a session.
  final int days;

  /// Days since the last completed session (0 = today). Also 0 for a user who
  /// never finished one; check [hasEverGrown].
  final int restedDays;

  final bool hasEverGrown;

  bool get isGrowing => days > 0;

  /// A full day or more with nothing. Never true for a brand new garden.
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
