/// The bounds one setting may take.
///
/// Ranges are values rather than a pair of loose constants because a control
/// needs all of a bound at once — its ends to size itself, and its clamp to
/// keep a value inside them. Passing the range around keeps the screen from
/// restating REQ-030's numbers next to the slider that enforces them.
///
/// [T] is anything ordered: [Duration] for the two lengths, [int] for the
/// long-break cycle.
final class SettingRange<T extends Comparable<Object>> {
  const SettingRange({required this.min, required this.max});

  /// The smallest value the setting may hold. Inclusive.
  final T min;

  /// The largest value the setting may hold. Inclusive.
  final T max;

  /// Whether [value] is within the bounds, which include their own ends.
  bool contains(T value) =>
      value.compareTo(min) >= 0 && value.compareTo(max) <= 0;

  /// [value], pulled to the nearest bound if it falls outside them.
  T clamp(T value) {
    if (value.compareTo(min) < 0) return min;
    if (value.compareTo(max) > 0) return max;
    return value;
  }

  @override
  String toString() => 'SettingRange($min..$max)';
}
