import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/page_header.dart';
import '../../design/paper_card.dart';
import '../../design/sky_band_backdrop.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../garden/plant_painter.dart';
import '../../garden/plant_palettes.dart';
import '../../garden/plant_providers.dart';
import '../../journal/journal_providers.dart';
import '../../shell/tab.dart';
import '../../shell/tab_glyph.dart';
import '../garden/garden_header.dart';
import 'journal_heatmap.dart';

/// The botanical journal: REQ-025 through REQ-029.
///
/// One scrollable page of three cut-paper cards under a band of sky, headed in
/// the same hand a plant's label is written in (PRD v2.3, Paper Theatre). It
/// is deliberately not a dashboard: there is no chart, no percentage, no
/// comparison with last week and nothing coloured red. Everything on it is a
/// count of things the user grew.
///
/// **Nothing on this screen is computed here.** The figures arrive as one
/// [Journal] out of `journalProvider`, which is six aggregate queries and the
/// domain's own values; the widgets below choose words and colours for them.
/// That division is what keeps a page of statistics testable without a widget
/// tree — see `packages/pomodoro_domain/test/journal/`.
///
/// **The tone is the requirement.** REQ-029 asks for a broken streak to be
/// described gently, and the way that is kept is that nothing here knows how to
/// say anything else: there is no copy in this file about missing, breaking,
/// failing or losing, and `test/features/journal/journal_screen_test.dart`
/// asserts on the whole rendered page rather than on one sentence.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.watch(journalProvider(firstDayOfWeekIn(context)));

    // No app bar: the tab bar already names the tab, and the top of the page
    // is better spent on a line about this journal, as the garden's is.
    return Scaffold(
      body: Stack(
        children: [
          const SkyBandBackdrop(depth: 0.24),
          SafeArea(
            bottom: false,
            child: journal.when(
              // A blank page rather than a spinner, on the same reasoning the
              // garden shows a blank sky: the read is six aggregates against
              // an indexed table, and a spinner that appears for a frame and a
              // half is worse than the paper that was going to be there anyway.
              loading: () => const SizedBox.expand(),
              error: (error, stack) => const _JournalUnreadable(),
              data: (journal) => journal.isEmpty
                  ? const _FirstPage()
                  : _JournalPage(journal: journal),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which day the user's locale starts a week on, as [DateTime.monday] through
/// [DateTime.sunday].
///
/// `MaterialLocalizations` counts from Sunday at zero and [DateTime] counts from
/// Monday at one; this is the one place the two conventions meet, so it is the
/// one place the conversion is written. The domain is given the [DateTime] form
/// because it already speaks it — [CalendarDay.weekday] is a `DateTime`
/// weekday — and because a zero that means Sunday is a footgun to pass around.
int firstDayOfWeekIn(BuildContext context) {
  final index = MaterialLocalizations.of(context).firstDayOfWeekIndex;
  return index == 0 ? DateTime.sunday : index;
}

/// What the journal holds, in a few words: "Thirteen plants, pressed."
///
/// The garden's own count, said the way the garden's headline says it, and for
/// the same reason: it is a number that only goes up.
String journalHeadline(int plants) {
  if (plants == 1) return 'One plant, pressed.';
  final words = GardenHeader.inWords(plants);
  return '${words[0].toUpperCase()}${words.substring(1)} plants, pressed.';
}

/// The three cards, in the order PRD §5.2 draws them.
class _JournalPage extends StatelessWidget {
  const _JournalPage({required this.journal});

  final Journal journal;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);

    return ListView(
      padding: PageHeader.pagePadding,
      children: [
        PageHeader(
          eyebrow: switch (journal.firstTended) {
            final first? =>
              'Kept since ${localizations.formatMonthYear(first.startsAt)}',
            null => null,
          },
          headline: journalHeadline(journal.lifetime.plants),
        ),
        _WeekCard(week: journal.week, streak: journal.streak),
        const SizedBox(height: Spacing.lg),
        _MonthCard(
          month: journal.month,
          today: journal.today,
          firstTended: journal.firstTended,
        ),
        const SizedBox(height: Spacing.lg),
        _LifetimeCard(lifetime: journal.lifetime),
      ],
    );
  }
}

/// REQ-026: sessions this week, the time they came to, the plants they grew and
/// the streak across them.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week, required this.streak});

  final JournalWeek week;
  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);

    return _JournalCard(
      heading: 'This week',
      taped: true,
      note: _dates(localizations),
      children: [
        Text(
          week.sessions == 0
              // Said as a beginning rather than as a shortfall. A week with
              // nothing in it yet is most of a week left.
              ? 'Nothing planted yet this week.'
              : '${_sessions(week.sessions)} · ${focusLabel(week.focus)}',
          style: theme.textTheme.bodyMedium,
        ),
        if (week.plants.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          _PlantsGrown(plants: week.plants),
        ],
        const SizedBox(height: Spacing.md),
        _StreakLine(streak: streak),
      ],
    );
  }

  /// The seven days, as the user's locale writes them.
  String _dates(MaterialLocalizations localizations) =>
      '${localizations.formatShortMonthDay(week.range.first.startsAt)} – '
      '${localizations.formatShortMonthDay(week.range.last.startsAt)}';

  static String _sessions(int count) =>
      count == 1 ? '1 session' : '$count sessions';
}

/// REQ-029, in one line and without a single hard word in it.
class _StreakLine extends StatelessWidget {
  const _StreakLine({required this.streak});

  final Streak streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);
    final resting = streak.isResting;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabGlyph(
          AppTab.garden,
          size: IconSizes.inline,
          color: resting ? colors.textSecondary : colors.foliage,
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            sentence,
            style: theme.textTheme.bodySmall?.copyWith(
              color: resting ? colors.textSecondary : colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// What the streak says.
  ///
  /// REQ-029's own example is the second case, word for word. The first is a
  /// count and not a congratulation, and there is deliberately no third case
  /// for "you were doing so well" — an app that notices a longest streak is an
  /// app that can hold it over somebody.
  String get sentence {
    if (streak.isGrowing) {
      return streak.days == 1
          ? '1 day in a row.'
          : '${streak.days} days in a row.';
    }
    if (streak.isResting) {
      return streak.restedDays == 1
          ? 'Your garden rested for a day.'
          : 'Your garden rested for ${streak.restedDays} days.';
    }
    // Reachable only from a garden with plants and no completed sessions in it,
    // which nothing in this app produces. Says the true thing anyway.
    return 'Your garden is waiting for its first session.';
  }
}

/// The week's plants, drawn rather than counted.
class _PlantsGrown extends StatelessWidget {
  const _PlantsGrown({required this.plants});

  final List<Plant> plants;

  /// How big one plant is drawn in the row.
  static const double _side = 40;

  /// How many are drawn before the rest become a number.
  ///
  /// A bound on the layout rather than on the truth: a week of thirty sessions
  /// is a real week, and thirty sprites wrapping over four lines would push the
  /// month off the screen.
  static const int maximumDrawn = 14;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final drawn = plants.take(maximumDrawn).toList();
    final rest = plants.length - drawn.length;

    return Semantics(
      label: plants.length == 1
          ? '1 plant grown this week'
          : '${plants.length} plants grown this week',
      excludeSemantics: true,
      child: Wrap(
        spacing: Spacing.xs,
        runSpacing: Spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final plant in drawn)
            SizedBox.square(dimension: _side, child: _PressedPlant(plant)),
          if (rest > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
              child: Text('+$rest', style: theme.textTheme.labelSmall),
            ),
        ],
      ),
    );
  }
}

/// One plant, at the size a page can hold a row of them.
///
/// Drawn through the registry like every other plant on screen — the journal is
/// not allowed to know what a tulip looks like any more than the garden is.
class _PressedPlant extends ConsumerWidget {
  const _PressedPlant(this.plant);

  final Plant plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomPaint(
      painter: PlantPainter(
        sprite: ref.watch(plantSpriteRegistryProvider).spriteFor(
              type: plant.type,
              stage: plant.stage,
            ),
        palette: plantPaletteFor(context, plant.species),
      ),
    );
  }
}

/// The journal's controls, by name.
abstract final class JournalKeys {
  /// REQ-027's arrows on the month heatmap.
  static const Key previousMonth = Key('journal.month.previous');
  static const Key nextMonth = Key('journal.month.next');
}

/// REQ-027: the month, as a grid of days, and the arrows that step back
/// through the months before it.
///
/// Which month is showing is this card's own state, counted in months back
/// from today's: it is a place the user is looking, not a setting, so it is
/// never stored and a launch always opens on the current month.
class _MonthCard extends ConsumerStatefulWidget {
  const _MonthCard({
    required this.month,
    required this.today,
    required this.firstTended,
  });

  /// The current month, as the journal already read it.
  final JournalMonth month;
  final CalendarDay today;

  /// The earliest day with a session on it: the oldest month worth showing.
  final CalendarDay? firstTended;

  @override
  ConsumerState<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends ConsumerState<_MonthCard> {
  /// How many months before today's the card is showing. Zero is this month.
  int _back = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final first = widget.today.firstOfMonth(monthsLater: -_back);

    // This month arrives with the journal. An earlier one is read when the user
    // steps to it, and until it arrives the grid is drawn as bare soil rather
    // than collapsing, so the arrows stay under the finger.
    final month = _back == 0
        ? widget.month
        : ref.watch(journalMonthProvider(first)).value ??
            JournalMonth.of(month: DayRange.month(first), sessionsByDay: {});

    final oldest = widget.firstTended?.firstOfMonth();
    final canGoBack = oldest != null && oldest.isBefore(first);

    return _JournalCard(
      heading: localizations.formatMonthYear(first.startsAt),
      actions: [
        IconButton(
          key: JournalKeys.previousMonth,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous month',
          onPressed: canGoBack ? () => setState(() => _back++) : null,
        ),
        IconButton(
          key: JournalKeys.nextMonth,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next month',
          onPressed: _back > 0 ? () => setState(() => _back--) : null,
        ),
      ],
      children: [
        JournalHeatmap(
          month: month,
          today: widget.today,
          firstDayOfWeek: firstDayOfWeekIn(context),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          _back == 0
              ? switch (month.daysTended) {
                  0 => 'A month of bare soil, so far.',
                  1 => 'One day tended this month.',
                  final days => '$days days tended this month.',
                }
              : switch (month.daysTended) {
                  0 => 'A month of bare soil.',
                  1 => 'One day tended that month.',
                  final days => '$days days tended that month.',
                },
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// REQ-028: the totals that only ever go up.
class _LifetimeCard extends StatelessWidget {
  const _LifetimeCard({required this.lifetime});

  final JournalLifetime lifetime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _JournalCard(
      heading: 'Lifetime',
      children: [
        for (final line in [_work, _plants, _garden])
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Text(line, style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }

  /// Every session ever finished, and every hour of them.
  String get _work {
    final sessions = lifetime.sessions == 1
        ? '1 session'
        : '${lifetime.sessions} sessions';
    return '$sessions · ${focusLabel(lifetime.focus)}';
  }

  /// The level, and the soil it opened. REQ-028 and REQ-018 are one rule read
  /// twice, so they are said in one line.
  String get _garden {
    final plots =
        lifetime.plots == 1 ? '1 plot' : '${lifetime.plots} plots';
    return 'Garden level ${lifetime.gardenLevel} · $plots';
  }

  /// The garden, with the awards counted out of it rather than folded in.
  ///
  /// REQ-021's rule said in a sentence: a garden of forty plants where seven
  /// were awarded is not forty afternoons of work, and a line that implied it
  /// was would be the app flattering the user with their own sessions.
  String get _plants {
    final plants =
        lifetime.plants == 1 ? '1 plant' : '${lifetime.plants} plants';
    if (lifetime.bonusPlants == 0) return plants;
    return lifetime.bonusPlants == 1
        ? '$plants · 1 of them a bonus plant'
        : '$plants · ${lifetime.bonusPlants} of them bonus plants';
  }
}

/// A card on the page: a handwritten heading, an optional note beside it, and
/// whatever the card has to say.
///
/// Cut paper laid on the page, as the garden's card is ([PaperCard]). The
/// first card is held down with a strip of tape, the way a page in a real
/// journal would be: one thing on the screen that is plainly stuck there by
/// hand.
class _JournalCard extends StatelessWidget {
  const _JournalCard({
    required this.heading,
    required this.children,
    this.note,
    this.actions = const [],
    this.taped = false,
  });

  final String heading;

  /// Controls beside the heading, at its right. Only the month has any.
  final List<Widget> actions;

  /// The small print under the heading — a date range, usually.
  final String? note;

  /// Whether a strip of tape holds the card down.
  final bool taped;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);

    final card = PaperCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.md,
          Spacing.md,
          Spacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    heading,
                    // REQ-025's handwritten header, and the only place other
                    // than a plant's label that §5.1's second face is used.
                    style: GardenTypography.journalHeading.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                ...actions,
              ],
            ),
            if (note case final note?)
              Text(note, style: theme.textTheme.labelSmall),
            const SizedBox(height: Spacing.sm),
            ...children,
          ],
        ),
      ),
    );
    if (!taped) return card;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        const Positioned(
          top: -Spacing.sm,
          right: Spacing.xl,
          child: ExcludeSemantics(child: _Tape()),
        ),
      ],
    );
  }
}

/// A strip of tape, a little askew.
class _Tape extends StatelessWidget {
  const _Tape();

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;

    return Transform.rotate(
      angle: 0.07,
      child: SizedBox(
        width: 64,
        height: 20,
        child: ColoredBox(
          color: Theme.of(context)
              .colorScheme
              .secondary
              .withValues(alpha: night ? 0.55 : 0.6),
        ),
      ),
    );
  }
}

/// The first page of a journal nobody has written in yet.
///
/// Not three cards of zeroes. A brand-new user has done nothing wrong, and a
/// screen that opened on `0 sessions · 0h · Garden level 1` would be the app's
/// first act being to measure them against nothing.
class _FirstPage extends StatelessWidget {
  const _FirstPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = GardenColors.of(context);

    return ListView(
      padding: PageHeader.pagePadding,
      children: [
        const PageHeader(headline: 'Your journal'),
        PaperCard(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Column(
              children: [
                TabGlyph(
                  AppTab.journal,
                  size: IconSizes.hero,
                  color: colors.foliage,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  'Nothing pressed between these pages yet.',
                  textAlign: TextAlign.center,
                  style: GardenTypography.journalHeading.copyWith(
                    color: colors.textPrimary,
                    fontSize: 21,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Finish a session and this page fills in: your week, the '
                  'days you tended and everything you\'ve grown.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// What the tab shows when the figures cannot be read off the disk.
///
/// The same reasoning the garden's unreadable state uses: a launch that cannot
/// read one thing should still open, and the user's sessions are not gone —
/// this build could not count them.
class _JournalUnreadable extends StatelessWidget {
  const _JournalUnreadable();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: Spacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabGlyph(
              AppTab.journal,
              size: IconSizes.hero,
              color: GardenColors.of(context).textSecondary,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Your journal couldn\'t be opened just now. Nothing\'s lost. Try '
              'again in a moment.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// A stretch of focus, as a journal writes it: `5h 20m`, `45m`, `143h`.
///
/// Hours and minutes and nothing smaller. A journal is read in glances, and
/// seconds on a lifetime total would be false precision about a number that
/// changes twelve hundred at a time.
String focusLabel(Duration focus) {
  final hours = focus.inHours;
  final minutes = focus.inMinutes % Duration.minutesPerHour;

  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}
