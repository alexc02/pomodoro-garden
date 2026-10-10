/// A source of the current wall-clock instant.
///
/// The domain never calls [DateTime.now] directly. Every time-dependent rule —
/// the session state machine, growth interpolation, streak boundaries — reads
/// the instant through a [Clock] so a test can supply one it controls.
///
/// Instants are UTC. A focus session is anchored to an absolute instant rather
/// than accumulated from ticks, so it has to survive the device changing
/// timezone or crossing a DST boundary mid-session; local time does not.
/// Convert to local time at the presentation edge, not here.
abstract interface class Clock {
  /// The current instant, in UTC.
  DateTime now();
}

/// The [Clock] backed by the device clock. The only implementation that reaches
/// outside the process, and the one the app injects in production.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// A [Clock] that stands still until a test moves it.
///
/// This is test scaffolding that deliberately ships in `lib/` rather than
/// `test/`: the app's own widget tests and later tickets' domain tests both
/// need it, and a package's `test/` directory is not importable from outside.
final class FixedClock implements Clock {
  FixedClock(DateTime instant) : _instant = instant.toUtc();

  DateTime _instant;

  @override
  DateTime now() => _instant;

  /// Moves the clock forward by [delta]. Rewinding is not supported — no rule
  /// in this domain is defined against time running backwards.
  void advance(Duration delta) {
    if (delta.isNegative) {
      throw ArgumentError.value(delta, 'delta', 'must not be negative');
    }
    _instant = _instant.add(delta);
  }
}
