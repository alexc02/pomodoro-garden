/// Hemisphere, inferred from the device time zone's DST so we never need
/// location.
enum Hemisphere {
  northern,
  southern;

  /// DST moves clocks forward in summer, so a larger July offset means north.
  /// Zones without DST (most of the world) fall back to [northern].
  static Hemisphere fromDaylightSaving({
    required Duration january,
    required Duration july,
  }) =>
      january > july ? southern : northern;
}

/// Meteorological season: three whole months each, turning at midnight on
/// the first. Derived from the date only, never stored.
enum Season {
  spring('Spring'),
  summer('Summer'),
  autumn('Autumn'),
  winter('Winter');

  const Season(this.label);

  final String label;

  /// [date] is local. The one place the domain uses local time on purpose.
  static Season on(
    DateTime date, {
    Hemisphere hemisphere = Hemisphere.northern,
  }) {
    final northern = _northernQuarters[date.month ~/ 3 % _northernQuarters.length];
    return switch (hemisphere) {
      Hemisphere.northern => northern,
      Hemisphere.southern => northern.opposite,
    };
  }

  /// Two seasons over. Southern seasons are just the northern ones relabelled.
  Season get opposite => values[(index + 2) % values.length];

  /// Next season change strictly after [date] (local), so a timer set to it
  /// can't refire. No hemisphere needed: both turn on the same days.
  static DateTime boundaryAfter(DateTime date) =>
      // Next 1st of a month divisible by 3. December gives month 15, which
      // DateTime rolls into March.
      DateTime(date.year, date.month + 3 - date.month % 3);

  /// Indexed by `month ~/ 3`; December (index 4) wraps back to winter.
  static const List<Season> _northernQuarters = [
    winter,
    spring,
    summer,
    autumn,
  ];
}
