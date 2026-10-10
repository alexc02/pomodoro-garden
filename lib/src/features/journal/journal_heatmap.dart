import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';

/// REQ-027: a month of days, each shaded by how much was grown in it.
///
/// A calendar rather than a chart. The days sit where they sat on the user's
/// own month — under the right weekday, and starting where their locale
/// starts the week — because the thing being shown is *their* month and not a
/// series of bars. Empty days are drawn as bare soil rather than left out,
/// which is the requirement's own wording and the whole of its tone: a day
/// nothing happened in is ground waiting for something, not a gap in a record.
///
/// The grid carries no numbers. A journal is not a wall planner, and a month
/// drawn as a shape is what the requirement asks for.
///
/// **It is spoken as one sentence, not as thirty-one cells.** A card merges the
/// semantics of everything inside it, so a label per day would be read out as
/// "Saturday, August the first, no sessions" thirty-one times over — a minute
/// of speech to learn that a month was quiet. The grid says what it is and how
/// full it got, and the line beneath it says how many days had something in
/// them; between them that is everything the picture holds.
class JournalHeatmap extends StatelessWidget {
  const JournalHeatmap({
    required this.month,
    required this.today,
    required this.firstDayOfWeek,
    super.key,
  });

  /// The month, and how much was done on each of its days.
  final JournalMonth month;

  /// Today, so the day the user is living in can be marked.
  final CalendarDay today;

  /// [DateTime.monday] through [DateTime.sunday], from the user's locale.
  final int firstDayOfWeek;

  /// The gap between two cells.
  static const double _gutter = Spacing.xs;

  /// What the grid says when it is read out.
  String get spoken => month.busiestDay == 0
      ? 'A calendar of the month, all of it bare soil so far.'
      : 'A calendar of the month, each day shaded by how much was grown in it, '
          'up to ${month.busiestDay} '
          '${month.busiestDay == 1 ? 'session' : 'sessions'} in a day.';

  @override
  Widget build(BuildContext context) {
    final days = month.range.eachDay;
    // How many cells of nothing come before the first of the month, so that it
    // lands under its own weekday.
    final leading =
        (days.first.weekday - firstDayOfWeek + DateTime.daysPerWeek) %
            DateTime.daysPerWeek;

    final cells = <CalendarDay?>[
      for (var blank = 0; blank < leading; blank++) null,
      ...days,
    ];

    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeekdayHeadings(firstDayOfWeek: firstDayOfWeek),
          const SizedBox(height: _gutter),
          for (var start = 0;
              start < cells.length;
              start += DateTime.daysPerWeek)
            Padding(
              padding: const EdgeInsets.only(bottom: _gutter),
              child: Row(
                children: [
                  for (var column = 0;
                      column < DateTime.daysPerWeek;
                      column++) ...[
                    if (column > 0) const SizedBox(width: _gutter),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: switch (start + column < cells.length
                            ? cells[start + column]
                            : null) {
                          // Before the first of the month and after the last:
                          // nothing at all, not even soil. Those days are not
                          // part of this page.
                          null => const SizedBox.shrink(),
                          final day => HeatmapDay(
                              day: day,
                              sessions: month.sessionsOn(day),
                              busiestDay: month.busiestDay,
                              isToday: day == today,
                            ),
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One day of the month.
class HeatmapDay extends StatelessWidget {
  const HeatmapDay({
    required this.day,
    required this.sessions,
    required this.busiestDay,
    required this.isToday,
    super.key,
  });

  final CalendarDay day;

  /// How many sessions were completed on it.
  final int sessions;

  /// The most any day of this month holds, which the shading is scaled to.
  final int busiestDay;

  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final colors = GardenColors.of(context);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: heatmapShade(
          sessions: sessions,
          busiestDay: busiestDay,
          colors: colors,
          paper: theme.scaffoldBackgroundColor,
        ),
        borderRadius: BorderRadius.circular(Radii.sm),
        // Today is ringed rather than filled, so it says "here" without saying
        // "a session happened".
        border: isToday
            ? Border.all(color: colors.textSecondary, width: 1.5)
            : null,
      ),
    );
  }
}

/// The colour a day is drawn in: bare soil, or one of four greens.
///
/// Scaled to [busiestDay] rather than to a fixed number of sessions, so a month
/// whose best day was three is drawn as fully as one whose best day was twelve.
/// The user is being shown the shape of their own month; there is nobody else's
/// to be measured against.
///
/// Four bands rather than a continuous ramp, because two adjacent days that
/// differ by one session should differ visibly, and a smooth gradient over a
/// range of two or three would not.
Color heatmapShade({
  required int sessions,
  required int busiestDay,
  required GardenColors colors,
  required Color paper,
}) {
  if (sessions <= 0 || busiestDay <= 0) {
    // REQ-027's "empty days = bare soil color". Mixed into the page rather than
    // laid on top of it: a month of full-strength soil would read as a month of
    // work done in mud.
    return Color.lerp(paper, colors.soil, 0.22)!;
  }

  const bands = [0.34, 0.56, 0.78, 1.0];
  final share = sessions / busiestDay;
  final band = (share * bands.length).ceil().clamp(1, bands.length);

  return Color.lerp(paper, colors.foliage, bands[band - 1])!;
}

/// The row of weekday initials over the grid, starting where the locale starts
/// the week.
class _WeekdayHeadings extends StatelessWidget {
  const _WeekdayHeadings({required this.firstDayOfWeek});

  final int firstDayOfWeek;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);

    return Row(
      children: [
        for (var column = 0; column < DateTime.daysPerWeek; column++) ...[
          if (column > 0) const SizedBox(width: JournalHeatmap._gutter),
          Expanded(
            child: ExcludeSemantics(
              // The grid above speaks for itself; a screen reader walking this
              // row would hear seven single letters and learn nothing.
              child: Text(
                // `narrowWeekdays` is indexed from Sunday, which is not where
                // every week starts — the offset is what turns the locale's
                // first day into the first column.
                localizations.narrowWeekdays[
                  (firstDayOfWeek + column) % DateTime.daysPerWeek
                ],
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
