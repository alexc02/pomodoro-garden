import 'dart:math';

/// A source of identifiers for the records the domain creates.
///
/// A port for the same reason `Clock` is one: generating an id reaches for
/// randomness, and a test that cannot predict the id it is about to assert on
/// has to match loosely or not at all.
abstract interface class IdSource {
  /// An identifier unique among every identifier this source has produced.
  String newId();
}

/// The [IdSource] the app runs on: random version 4 UUIDs.
///
/// Random rather than sequential because these ids identify rows that a later
/// ticket exports and, one day, may sync — and a counter collides the moment
/// two devices both count from one. Hand-rolled rather than taking a
/// dependency: it is sixteen bytes and two masks, and this package's rule is
/// that anything it depends on must be pure Dart and worth the weight.
final class RandomIdSource implements IdSource {
  RandomIdSource([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    // RFC 9562 §5.4: version 4 in the high nibble of octet 6, variant 10xx in
    // the high bits of octet 8. Everything else is random.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = [
      for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
    ].join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

/// An [IdSource] that counts: `1`, `2`, `3`.
///
/// Test scaffolding that ships in `lib/` alongside `FixedClock`, and for the
/// same reason — the app's own tests need it, and a package's `test/` directory
/// is not importable from outside.
final class SequentialIdSource implements IdSource {
  int _next = 0;

  @override
  String newId() => '${++_next}';
}
