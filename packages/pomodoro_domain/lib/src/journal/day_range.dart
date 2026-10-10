import 'calendar_day.dart';

/// A run of consecutive days, both ends included — a week, or a month.
///
/// Two things at once, and deliberately: the days themselves, which is what a
/// heatmap draws a cell per, and the pair of instants a query filters on. They
/// are the same fact, and keeping them together is what stops a card that
/// *shows* one week from being filled by a query that *counted* another.
///
/// The instants are derived from local midnights ([from], [until]), so a range
/// containing a daylight-saving change is an hour longer or shorter in elapsed
/// time than the same range in the month before it. That is correct: the user's
/// week ended when their own clock said it did.
final class DayRange {
  const DayRange({required this.first, required this.last});

  /// The week [day] falls in, starting on [firstDayOfWeek].
  ///
  /// [firstDayOfWeek] is one of [DateTime.monday] through [DateTime.sunday],
  /// and comes from the user's locale rather than from a constant here: a week
  /// starts on Monday in Berlin, Sunday in Chicago and Saturday in Cairo, and
  /// all three are right. The app reads it off `MaterialLocalizations`.
  factory DayRange.week(CalendarDay day, {required int firstDayOfWeek}) {
    final into = (day.weekday - firstDayOfWeek + DateTime.daysPerWeek) %
        DateTime.daysPerWeek;
    final first = day.plus(-into);
    return DayRange(first: first, last: first.plus(DateTime.daysPerWeek - 1));
  }

  /// The whole calendar month [day] falls in.
  ///
  /// The last day is found by stepping back from the first of the next month,
  /// so nothing here knows how long February is.
  factory DayRange.month(CalendarDay day) {
    final first = CalendarDay(day.year, day.month, 1);
    final nextMonth = CalendarDay(day.year, day.month + 1, 1);
    return DayRange(first: first, last: nextMonth.yesterday);
  }

  /// The first day in the range.
  final CalendarDay first;

  /// The last day in the range, and part of it.
  final CalendarDay last;

  /// How many days the range covers, [first] and [last] included.
  int get days => first.daysUntil(last) + 1;

  /// Every day in the range, in order. What a calendar grid is drawn from.
  List<CalendarDay> get eachDay =>
      List.unmodifiable([for (var n = 0; n < days; n++) first.plus(n)]);

  bool contains(CalendarDay day) => !day.isBefore(first) && !day.isAfter(last);

  /// The instant the range begins: local midnight on [first], as UTC.
  ///
  /// UTC because that is what the sessions table stores (ADR 0001), and a
  /// half-open pair of instants is what makes a range query an index range
  /// rather than a function applied to every row.
  DateTime get from => first.startsAt.toUtc();

  /// The instant the range ends, **exclusive**: local midnight on the day after
  /// [last], as UTC.
  ///
  /// Exclusive so that a session anchored exactly at midnight belongs to the
  /// day that is starting and is counted once, in one range, rather than in
  /// both or neither.
  DateTime get until => last.tomorrow.startsAt.toUtc();

  @override
  bool operator ==(Object other) =>
      other is DayRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => 'DayRange($first..$last)';
}
