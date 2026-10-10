/// Which half of the world the device is in, and so which way round the
/// calendar's seasons run.
///
/// The app never asks the user and never asks for a location. It reads the
/// device's time zone, which is a setting every phone already has and which no
/// permission gates, and infers the hemisphere from the one thing a time zone
/// says about latitude: *when* it puts its clocks forward. See
/// `docs/adr/0011-the-season-is-derived-from-the-device-date.md` for why that is
/// the signal, and what it costs when there is none.
enum Hemisphere {
  northern,
  southern;

  /// The hemisphere a zone is in, judged by which of its two offsets is the
  /// summer one.
  ///
  /// Daylight saving moves a clock *forward* in that zone's summer, so a zone
  /// whose July offset is the larger keeps a northern summer and one whose
  /// January offset is the larger keeps a southern one.
  ///
  /// Equal offsets mean the zone does not observe daylight saving at all, which
  /// is true of most of the world — India, China, almost all of Africa, Brazil
  /// since 2019 — and there is nothing left in a time zone to read. Those fall
  /// back to [northern], which is REQ-019's own reading of the calendar and
  /// what the app would show if it never looked. The fallback is therefore
  /// never worse than not asking, and a great many of the zones it cannot read
  /// are tropical ones where a four-season calendar is a fiction either way.
  static Hemisphere fromDaylightSaving({
    required Duration january,
    required Duration july,
  }) =>
      january > july ? southern : northern;
}

/// The season the garden is in: REQ-019.
///
/// Meteorological rather than astronomical — three whole months each, turning
/// at midnight on the first — because the alternative is solstice arithmetic
/// that moves the boundary by a day or two a year and buys nothing anybody
/// looking at a garden could see. It also makes a boundary an instant a timer
/// can be aimed at exactly.
///
/// A season is a property of the *date*, never of anything stored. Nothing
/// records which season a plant was grown in and nothing needs to: a garden
/// opened next November is an autumn garden, whenever its plants went in. That
/// is also the whole of why the season cannot reach the rest of the app — there
/// is nothing for it to write on.
enum Season {
  spring('Spring'),
  summer('Summer'),
  autumn('Autumn'),
  winter('Winter');

  const Season(this.label);

  /// What to call this season in front of the user.
  final String label;

  /// The season [date] falls in.
  ///
  /// [date] is a *local* date — the one on the device's calendar — because a
  /// season is what is outside the user's window rather than what UTC thinks.
  /// This is the one rule in the domain that wants local time; the session
  /// machine is anchored in UTC, and for the opposite reason.
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

  /// The season half a year from this one: spring's is autumn, summer's is
  /// winter.
  ///
  /// What makes the southern hemisphere a relabelling rather than a second
  /// table — the two halves of the world are always exactly two seasons apart,
  /// and writing that down once means they cannot drift.
  Season get opposite => values[(index + 2) % values.length];

  /// The first instant after [date] at which the season changes.
  ///
  /// Local, and strictly after: asked *on* a boundary it gives the next one, so
  /// a timer aimed here cannot fire in a loop at the moment it arrives.
  ///
  /// It takes no [Hemisphere], and that is the point rather than an omission:
  /// the southern seasons are the northern ones under different names, so both
  /// halves of the world turn on the same four days. A parameter here would be
  /// one a caller could pass and be misled by.
  static DateTime boundaryAfter(DateTime date) =>
      // The season-start months are 3, 6, 9 and 12, so the next boundary is the
      // first of the next month whose number is a multiple of three — and a
      // date already in one of those months rounds up to the one after, which
      // is what makes this strictly later than [date]. December rounds to a
      // fifteenth month; `DateTime` carries that into March of the next year.
      DateTime(date.year, date.month + 3 - date.month % 3);

  /// The four northern seasons, one per quarter of the year counted from
  /// January.
  ///
  /// Winter first, because January and February are in it — and December is in
  /// it too, which is the quarter that wraps: `12 ~/ 3` is a fifth quarter, and
  /// the modulo brings it back to the first.
  static const List<Season> _northernQuarters = [
    winter,
    spring,
    summer,
    autumn,
  ];
}
