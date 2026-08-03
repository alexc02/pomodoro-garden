/// Wall-clock source. The domain never calls [DateTime.now] directly, so tests
/// can control time.
///
/// Always UTC: sessions are anchored to absolute instants and must survive
/// time zone and DST changes. Convert to local at the UI edge.
abstract interface class Clock {
  /// UTC.
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// A clock that only moves when told. Lives in `lib/` so the app's tests can
/// use it too.
final class FixedClock implements Clock {
  FixedClock(DateTime instant) : _instant = instant.toUtc();

  DateTime _instant;

  @override
  DateTime now() => _instant;

  /// Forward only; throws on a negative [delta].
  void advance(Duration delta) {
    if (delta.isNegative) {
      throw ArgumentError.value(delta, 'delta', 'must not be negative');
    }
    _instant = _instant.add(delta);
  }
}
