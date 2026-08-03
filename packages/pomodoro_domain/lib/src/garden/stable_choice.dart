/// Deterministic number in `[0, 1)` from [seed].
///
/// Used instead of `Random` so per-plant picks (species, sway phase) don't
/// change between rebuilds. Hand-rolled instead of [Object.hashCode] because
/// it has to match across platforms and Dart versions.
double stableFraction(String seed) => _hash(seed) / _twoToThe32;

/// Picks from [options] by [seed]. Throws [ArgumentError] if empty.
T stableChoice<T>(List<T> options, String seed) {
  if (options.isEmpty) {
    throw ArgumentError.value(options, 'options', 'must not be empty');
  }
  return options[(stableFraction(seed) * options.length).floor()];
}

const int _twoToThe32 = 0x100000000;

/// FNV-1a plus murmur3's finaliser. Plain FNV-1a barely moves the high bits
/// for short seeds, so '1', '2', '3' would all pick the same species.
int _hash(String seed) {
  var hash = 0x811c9dc5;

  for (final unit in seed.codeUnits) {
    hash = _multiply(hash ^ unit, 0x01000193);
  }

  hash = _multiply(hash ^ (hash >>> 16), 0x85ebca6b);
  hash = _multiply(hash ^ (hash >>> 13), 0xc2b2ae35);
  return hash ^ (hash >>> 16);
}

/// 32-bit multiply in 16-bit halves so it stays exact on the web (53-bit
/// ints).
int _multiply(int a, int b) {
  final low = (a & 0xffff) * b;
  final high = ((a >>> 16) * b) & 0xffff;
  return (low + (high << 16)) & 0xffffffff;
}
