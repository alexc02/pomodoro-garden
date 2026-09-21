import 'package:flutter/material.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/spacing.dart';

/// A month as a calendar grid, each day shaded by sessions. Laid out under the
/// locale's weekdays; empty days are bare soil, not gaps. No numbers.
///
/// Read out as one sentence ([spoken]) rather than 31 cells, which would be a
/// minute of speech.
class JournalHeatmap extends StatelessWidget {
  const JournalHeatmap({
    required this.month,
    required this.today,
    required this.firstDayOfWeek,
    super.key,
  });

  final JournalMonth month;

  /// Ringed in the grid.
  final CalendarDay today;

  /// [DateTime.monday] through [DateTime.sunday], from the user's locale.
  final int firstDayOfWeek;

  static const double _gutter = Spacing.xs;

  String get spoken => month.busiestDay == 0
      ? 'A calendar of the month, all of it bare soil so far.'
      : 'A calendar of the month, each day shaded by how much was grown in it, '
          'up to ${month.busiestDay} '
          '${month.busiestDay == 1 ? 'session' : 'sessions'} in a day.';

  @override
  Widget build(BuildContext context) {
    final days = month.range.eachDay;
    // Blank cells before the 1st so it lands under its weekday.
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
                          // Outside the month: nothing, not even soil.
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

class HeatmapDay extends StatelessWidget {
  const HeatmapDay({
    required this.day,
    required this.sessions,
    required this.busiestDay,
    required this.isToday,
    super.key,
  });

  final CalendarDay day;

  final int sessions;

  /// Max sessions on any day this month; shading is relative to it.
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
        // Today gets a marigold ring rather than a fill, so it doesn't look
        // like a session.
        border: isToday
            ? Border.all(color: theme.colorScheme.secondary, width: 2)
            : null,
      ),
    );
  }
}

/// Bare soil, or one of four greens scaled to [busiestDay] (so every month
/// uses the full range). Bands rather than a smooth ramp so a one-session
/// difference is visible.
Color heatmapShade({
  required int sessions,
  required int busiestDay,
  required GardenColors colors,
  required Color paper,
}) {
  if (sessions <= 0 || busiestDay <= 0) {
    // Soil mixed into the paper; full-strength soil looks like mud.
    return Color.lerp(paper, colors.soil, 0.22)!;
  }

  const bands = [0.34, 0.56, 0.78, 1.0];
  final share = sessions / busiestDay;
  final band = (share * bands.length).ceil().clamp(1, bands.length);

  return Color.lerp(paper, colors.foliage, bands[band - 1])!;
}

/// Weekday initials, starting on the locale's first day.
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
              // The grid's label covers it; seven letters add nothing.
              child: Text(
                // `narrowWeekdays` starts at Sunday, hence the offset.
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
