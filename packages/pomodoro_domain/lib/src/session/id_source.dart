import 'dart:math';

/// Id generator. A port so tests get predictable ids.
abstract interface class IdSource {
  String newId();
}

/// Random v4 UUIDs. Random so ids won't collide if we ever sync across
/// devices; hand-rolled to avoid a dependency.
final class RandomIdSource implements IdSource {
  RandomIdSource([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    // RFC 9562: version 4 in the high nibble of octet 6, variant 10xx in the
    // high bits of octet 8.
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

/// Yields `1`, `2`, `3`... In `lib/` so the app's tests can use it.
final class SequentialIdSource implements IdSource {
  int _next = 0;

  @override
  String newId() => '${++_next}';
}
