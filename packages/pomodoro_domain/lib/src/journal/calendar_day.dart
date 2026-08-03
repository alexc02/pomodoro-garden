/// A local calendar date with no time component.
///
/// Local on purpose: sessions are anchored in UTC (ADR 0001) but the journal
/// shows the user's own days. No duration arithmetic here, so 23h and 25h DST
/// days come out right. A session belongs to the day it started on.
final class CalendarDay implements Comparable<CalendarDay> {
  const CalendarDay(this.year, this.month, this.day);

  /// The local day [instant] falls on. Works for UTC or local input.
  factory CalendarDay.of(DateTime instant) {
    final local = instant.toLocal();
    return CalendarDay(local.year, local.month, local.day);
  }

  /// Parses `YYYY-MM-DD` (what SQLite's `date()` returns). Throws
  /// [FormatException] otherwise, since a bad string means a broken query.
  factory CalendarDay.parse(String iso) {
    final match = _iso.firstMatch(iso);
    if (match == null) {
      throw FormatException('Not an ISO YYYY-MM-DD date', iso);
    }
    return CalendarDay(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static final RegExp _iso = RegExp(r'^(\d{4,})-(\d{2})-(\d{2})$');

  final int year;

  final int month;

  final int day;

  /// Local midnight. On a spring-forward-over-midnight day this is the first
  /// instant that actually exists.
  DateTime get startsAt => DateTime(year, month, day);

  /// [DateTime.monday] to [DateTime.sunday]. Read from a UTC date so DST can't
  /// shift it.
  int get weekday => _asUtc.weekday;

  CalendarDay get tomorrow => plus(1);

  CalendarDay get yesterday => plus(-1);

  /// Negative counts back. Lets [DateTime] normalise the overflow instead of
  /// adding `Duration(days: n)`, which is off by a day around DST.
  CalendarDay plus(int days) =>
      CalendarDay.of(DateTime(year, month, day + days));

  /// First day of this month, or of the month [monthsLater] away.
  CalendarDay firstOfMonth({int monthsLater = 0}) =>
      CalendarDay.of(DateTime(year, month + monthsLater, 1));

  /// Whole days to [other], negative if earlier. Done in UTC so DST can't
  /// round it down.
  int daysUntil(CalendarDay other) =>
      other._asUtc.difference(_asUtc).inDays;

  bool isBefore(CalendarDay other) => compareTo(other) < 0;

  bool isAfter(CalendarDay other) => compareTo(other) > 0;

  /// For calendar arithmetic only, not a real moment.
  DateTime get _asUtc => DateTime.utc(year, month, day);

  @override
  int compareTo(CalendarDay other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// `YYYY-MM-DD`, the format [CalendarDay.parse] reads.
  @override
  String toString() => '${year.toString().padLeft(4, '0')}'
      '-${month.toString().padLeft(2, '0')}'
      '-${day.toString().padLeft(2, '0')}';
}
