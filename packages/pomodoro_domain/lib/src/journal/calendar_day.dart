/// One day on the device's own calendar: a date, with no time in it.
///
/// The journal counts days, and a day is the thing an instant is *not*. A
/// session anchored at 23:50 and one anchored at 00:10 are ten minutes apart
/// and belong to two different days; two sessions eleven hours apart can belong
/// to one. Nothing in this class holds a duration, and none of its arithmetic
/// is done in duration — which is what makes it right on the two days a year
/// a local day is twenty-three or twenty-five hours long.
///
/// It is deliberately **local**. The rest of this package anchors sessions to
/// UTC instants (ADR 0001) so a device changing time zone cannot move a
/// countdown; the journal is the presentation edge those rules point at, in the
/// same way [Season] is. A user who worked on Tuesday evening worked on
/// Tuesday, wherever UTC had got to.
///
/// Which day a session belongs to is written down in
/// `docs/adr/0012-a-day-in-the-journal-is-the-day-a-session-was-anchored.md`.
final class CalendarDay implements Comparable<CalendarDay> {
  const CalendarDay(this.year, this.month, this.day);

  /// The day [instant] falls on where the device is.
  ///
  /// Takes UTC or local and gives the same answer for either, because it
  /// converts first: a session's anchor is UTC, and the day it belongs to is
  /// the local one that anchor landed in.
  factory CalendarDay.of(DateTime instant) {
    final local = instant.toLocal();
    return CalendarDay(local.year, local.month, local.day);
  }

  /// The day an ISO `YYYY-MM-DD` string names.
  ///
  /// The inverse of [toString], and the shape SQLite's `date()` returns —
  /// which is what the journal's per-day queries group by, so this is how a
  /// grouped row becomes a day.
  ///
  /// Throws a [FormatException] on anything else. The only strings reaching
  /// here come from SQLite's own date function, so a malformed one is a bug in
  /// the query rather than bad data to be tolerated.
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

  /// 1 to 12.
  final int month;

  /// 1 to 31.
  final int day;

  /// Local midnight: the first instant of this day where the device is.
  ///
  /// Where a range turns into something a query can filter on — see
  /// [DayRange.from]. On the day a zone springs forward over midnight this is
  /// the first instant the day actually has, which is the same thing the user's
  /// clock did.
  DateTime get startsAt => DateTime(year, month, day);

  /// Which day of the week this is: [DateTime.monday] through
  /// [DateTime.sunday].
  ///
  /// Asked of a UTC date rather than a local one, because a weekday is a fact
  /// about the calendar and reading it off local midnight would be reading it
  /// off an instant a DST jump can move.
  int get weekday => _asUtc.weekday;

  CalendarDay get tomorrow => plus(1);

  CalendarDay get yesterday => plus(-1);

  /// The day [days] after this one; negative counts back.
  ///
  /// Built by letting [DateTime] normalise an out-of-range day-of-month, which
  /// is what carries 31 August into 1 September and February into a leap year
  /// without a table of month lengths here. Not `add(Duration(days: n))`, which
  /// adds twenty-four hours and lands on the wrong date twice a year.
  CalendarDay plus(int days) =>
      CalendarDay.of(DateTime(year, month, day + days));

  /// The first day of this day's month, or of the month [monthsLater] after it
  /// (before it, when negative). What REQ-027's month arrows step through.
  CalendarDay firstOfMonth({int monthsLater = 0}) =>
      CalendarDay.of(DateTime(year, month + monthsLater, 1));

  /// How many whole days from this one to [other]. Negative if [other] is
  /// earlier.
  ///
  /// Counted in UTC, where every day is exactly twenty-four hours long, so a
  /// clock change inside the span cannot round the answer down.
  int daysUntil(CalendarDay other) =>
      other._asUtc.difference(_asUtc).inDays;

  bool isBefore(CalendarDay other) => compareTo(other) < 0;

  bool isAfter(CalendarDay other) => compareTo(other) > 0;

  /// This date as a UTC instant — calendar arithmetic only, never a moment.
  DateTime get _asUtc => DateTime.utc(year, month, day);

  @override
  int compareTo(CalendarDay other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  /// Days compare by date, so the same day read off two rows is one day —
  /// which is what lets a set of them be the days a user worked.
  @override
  bool operator ==(Object other) =>
      other is CalendarDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  /// ISO `YYYY-MM-DD`: sortable as text, and the shape [CalendarDay.parse]
  /// reads back.
  @override
  String toString() => '${year.toString().padLeft(4, '0')}'
      '-${month.toString().padLeft(2, '0')}'
      '-${day.toString().padLeft(2, '0')}';
}
