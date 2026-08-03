import 'calendar_day.dart';

/// Consecutive days, both ends included (a week or a month).
///
/// [from] and [until] come from local midnights, so a range spanning a DST
/// change is an hour longer or shorter. That's intended.
final class DayRange {
  const DayRange({required this.first, required this.last});

  /// The week [day] falls in. [firstDayOfWeek] is [DateTime.monday] to
  /// [DateTime.sunday] and comes from the locale (`MaterialLocalizations`).
  factory DayRange.week(CalendarDay day, {required int firstDayOfWeek}) {
    final into = (day.weekday - firstDayOfWeek + DateTime.daysPerWeek) %
        DateTime.daysPerWeek;
    final first = day.plus(-into);
    return DayRange(first: first, last: first.plus(DateTime.daysPerWeek - 1));
  }

  factory DayRange.month(CalendarDay day) {
    final first = CalendarDay(day.year, day.month, 1);
    final nextMonth = CalendarDay(day.year, day.month + 1, 1);
    return DayRange(first: first, last: nextMonth.yesterday);
  }

  final CalendarDay first;

  final CalendarDay last;

  int get days => first.daysUntil(last) + 1;

  List<CalendarDay> get eachDay =>
      List.unmodifiable([for (var n = 0; n < days; n++) first.plus(n)]);

  bool contains(CalendarDay day) => !day.isBefore(first) && !day.isAfter(last);

  /// Local midnight on [first], in UTC (sessions are stored in UTC, ADR 0001).
  DateTime get from => first.startsAt.toUtc();

  /// Exclusive end: local midnight after [last], in UTC. Exclusive so a session
  /// at exactly midnight lands in one range only.
  DateTime get until => last.tomorrow.startsAt.toUtc();

  @override
  bool operator ==(Object other) =>
      other is DayRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => 'DayRange($first..$last)';
}
