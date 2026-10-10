/// A number in `[0, 1)` derived from [seed], the same every time.
///
/// The domain's only source of variety. Everything about a plant that should
/// look arbitrary — which species it is, how far its sway is offset from its
/// neighbour's — is decided from the plant's identity rather than from a
/// `Random`, because those decisions have to hold still. A species picked from
/// a `Random` would change on the next rebuild; a sway phase picked from one
/// would re-roll every time the garden was scrolled past.
///
/// The algorithm is written out here rather than delegated to
/// [Object.hashCode]: the same seed has to give the same fraction on every
/// platform, in every build mode and in every future version of Dart, and
/// `hashCode` promises none of that.
double stableFraction(String seed) => _hash(seed) / _twoToThe32;

/// The element of [options] that [seed] selects, the same every time.
///
/// Throws an [ArgumentError] if [options] is empty — an empty catalogue is a
/// wiring mistake, and returning null for it would push the mistake into
/// whatever tried to draw the result.
T stableChoice<T>(List<T> options, String seed) {
  if (options.isEmpty) {
    throw ArgumentError.value(options, 'options', 'must not be empty');
  }
  // Not a modulus of the hash: the fraction is the concept, and multiplying it
  // out keeps this reading as "somewhere along the list" rather than as a bit
  // trick. `floor` cannot reach `length` because the fraction never reaches 1.
  return options[(stableFraction(seed) * options.length).floor()];
}

const int _twoToThe32 = 0x100000000;

/// FNV-1a over the seed's UTF-16 code units, finished with murmur3's avalanche.
///
/// FNV-1a alone is not enough here. Its high bits barely move for short inputs,
/// and the high bits are exactly what [stableFraction] reads — seeds of '1',
/// '2', '3' would land almost on top of each other, which for a garden means
/// every plant the same species. The avalanche is what spreads them.
int _hash(String seed) {
  var hash = 0x811c9dc5;

  for (final unit in seed.codeUnits) {
    hash = _multiply(hash ^ unit, 0x01000193);
  }

  hash = _multiply(hash ^ (hash >>> 16), 0x85ebca6b);
  hash = _multiply(hash ^ (hash >>> 13), 0xc2b2ae35);
  return hash ^ (hash >>> 16);
}

/// [a] × [b], truncated to 32 bits.
///
/// Split into halves rather than multiplied outright because the product of two
/// 32-bit numbers needs 64 bits, and an `int` holds 53 of them on the web. The
/// split keeps every intermediate under 2^48, so a seed hashes the same
/// wherever it is hashed.
int _multiply(int a, int b) {
  final low = (a & 0xffff) * b;
  final high = ((a >>> 16) * b) & 0xffff;
  return (low + (high << 16)) & 0xffffffff;
}
