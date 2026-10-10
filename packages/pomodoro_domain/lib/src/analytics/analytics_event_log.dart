import 'analytics_event.dart';

/// One event as it comes back out of the log: what it was called, what it
/// carried, and when it happened.
///
/// **Read side only.** The write side is an [AnalyticsEvent], which is typed all
/// the way down; this is what a *stored row* looks like, and it is deliberately
/// flatter — a log holds rows written by whichever build was running at the
/// time, and a reader that insisted on turning every one of them back into a
/// typed event would be a reader that throws on a row from next year's version.
final class LoggedEvent {
  const LoggedEvent({
    required this.name,
    required this.parameters,
    required this.at,
  });

  /// The name the row carries, as it was stored.
  ///
  /// A string rather than an [AnalyticsEventName] for the reason above: every
  /// row this build wrote has a name in that enum, and a row it did not write
  /// may not. [known] is how a reader asks.
  final String name;

  /// The parameters the row carries — §7.1's, for whichever event this is.
  final Map<String, Object?> parameters;

  /// When it happened, in UTC.
  final DateTime at;

  /// This row's name, if this build knows it, or null if not.
  AnalyticsEventName? get known => AnalyticsEventName.named(name);

  @override
  String toString() => 'LoggedEvent($name at $at, $parameters)';
}

/// Where the events are kept: PRD §7.2's local table, as a port.
///
/// A repository like `SessionRepository` and `PlantRepository` — the domain says
/// what it needs of storage and the app supplies SQLite. It is separate from
/// [Analytics] because the two have different jobs and different callers:
/// everything in the app *records* through the port, and only the debug screen
/// and the app-open check ever talk to the log itself.
///
/// **There is no `clear` here, and that is ticket 22's doing.** REQ-036's reset
/// empties this table along with the plants, the sessions and the arrangement,
/// and it has to do all four in one transaction — a log that survived a reset
/// that half-failed would be the one place the app still remembered a garden the
/// user asked it to forget. So the emptying lives behind [GardenReset], where the
/// transaction is, and a second way to clear the log from here would be a way to
/// clear it *without* the rest.
///
/// **The log is bounded.** An app somebody keeps for four years must not carry a
/// table that grows a row per pause for all of it, and nothing here is a
/// history the user is entitled to — see [maximumEvents], which an
/// implementation is expected to enforce as it writes rather than in a sweep
/// somebody has to remember to schedule.
abstract interface class AnalyticsEventLog {
  /// How many events the log keeps. Older ones are dropped as newer ones
  /// arrive.
  ///
  /// Enough to hold weeks of ordinary use — a session start, its pauses and its
  /// completion come to a handful of rows — and small enough that the whole
  /// table is a few tens of kilobytes on the worst day anybody has.
  static const int maximumEvents = 500;

  /// Writes [event] down as having happened at [at], and drops whatever falls
  /// off the end of [maximumEvents].
  Future<void> append(AnalyticsEvent event, {required DateTime at});

  /// The most recent events, newest first, at most [limit] of them.
  ///
  /// [limit] defaults to the whole log, which is a bounded thing to ask for —
  /// that is what [maximumEvents] buys, and why a caller reading "everything"
  /// is not a caller reading four years of rows.
  Future<List<LoggedEvent>> recent({int limit = maximumEvents});

  /// When an event called [name] was last recorded, or null if the log holds
  /// none.
  ///
  /// Here so that "days since last open" can be answered by the log itself
  /// rather than by a column somebody has to remember to write — the app
  /// already records every open, and the last one is the answer. Typed, so a
  /// caller cannot ask for an event name that does not exist.
  Future<DateTime?> lastRecordedAt(AnalyticsEventName name);
}
