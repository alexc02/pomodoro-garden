/// Inclusive bounds for one setting, so the UI and the clamp share the
/// numbers.
final class SettingRange<T extends Comparable<Object>> {
  const SettingRange({required this.min, required this.max});

  /// Inclusive.
  final T min;

  /// Inclusive.
  final T max;

  bool contains(T value) =>
      value.compareTo(min) >= 0 && value.compareTo(max) <= 0;

  T clamp(T value) {
    if (value.compareTo(min) < 0) return min;
    if (value.compareTo(max) > 0) return max;
    return value;
  }

  @override
  String toString() => 'SettingRange($min..$max)';
}
