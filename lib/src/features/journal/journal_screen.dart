import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../design/garden_colors.dart';
import '../../design/headline.dart';
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

/// The journal: three paper cards under a band of sky. Not a dashboard: no
/// charts, no percentages, nothing red. Just counts of things the user grew.
///
/// All figures come from `journalProvider` as one [Journal]; this file only
/// picks words and colours. The copy never talks about missing or breaking a
/// streak, and the widget test checks the whole page for that.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journal = ref.watch(journalProvider(firstDayOfWeekIn(context)));

    return Scaffold(
      body: Stack(
        children: [
          const SkyBandBackdrop(depth: 0.24),
          SafeArea(
            bottom: false,
            child: journal.when(
              // Blank rather than a spinner; the read is a few indexed
              // aggregates and a one-frame spinner looks worse.
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

/// First day of the locale's week, as [DateTime.monday]..[DateTime.sunday].
///
/// `MaterialLocalizations` counts from Sunday = 0, [DateTime] from Monday = 1.
/// This is the only place that converts.
int firstDayOfWeekIn(BuildContext context) {
  final index = MaterialLocalizations.of(context).firstDayOfWeekIndex;
  return index == 0 ? DateTime.sunday : index;
}

/// Headline, e.g. "Thirteen plants, pressed."
String journalHeadline(int plants) {
  if (plants == 1) return 'One plant, pressed.';
  final words = GardenHeader.inWords(plants);
  return '${words[0].toUpperCase()}${words.substring(1)} plants, pressed.';
}

/// The three cards.
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

/// This week: sessions, focus time, plants grown and the streak.
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
              // Framed as a beginning, not a shortfall.
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

  String _dates(MaterialLocalizations localizations) =>
      '${localizations.formatShortMonthDay(week.range.first.startsAt)} – '
      '${localizations.formatShortMonthDay(week.range.last.startsAt)}';

  static String _sessions(int count) =>
      count == 1 ? '1 session' : '$count sessions';
}

/// The streak, in one gentle line.
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

  /// Deliberately no "longest streak" case; that's something an app can hold
  /// over somebody.
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
    // Plants but no completed sessions; shouldn't happen in practice.
    return 'Your garden is waiting for its first session.';
  }
}

class _PlantsGrown extends StatelessWidget {
  const _PlantsGrown({required this.plants});

  final List<Plant> plants;

  static const double _side = 40;

  /// Cap on sprites drawn before the rest become a "+N", so a busy week doesn't
  /// push the month card off screen.
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

/// One plant at row size, drawn through the registry like everywhere else.
class _PressedPlant extends ConsumerWidget {
  const _PressedPlant(this.plant);

  final Plant plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomPaint(
      painter: PlantPainter(
        sprite: ref.watch(plantSpriteRegistryProvider).spriteFor(
              form: plant.species.form,
              stage: plant.stage,
            ),
        palette: plantPaletteFor(context, plant.species),
      ),
    );
  }
}

abstract final class JournalKeys {
  static const Key previousMonth = Key('journal.month.previous');
  static const Key nextMonth = Key('journal.month.next');
}

/// The month as a grid of days, with arrows to step back. The offset is local
/// state, never stored, so a launch always opens on the current month.
class _MonthCard extends ConsumerStatefulWidget {
  const _MonthCard({
    required this.month,
    required this.today,
    required this.firstTended,
  });

  final JournalMonth month;
  final CalendarDay today;

  /// Earliest day with a session: the oldest month worth showing.
  final CalendarDay? firstTended;

  @override
  ConsumerState<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends ConsumerState<_MonthCard> {
  /// Months back from the current one. Zero is this month.
  int _back = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final first = widget.today.firstOfMonth(monthsLater: -_back);

    // Earlier months load on demand. Until they arrive the grid draws as bare
    // soil so the arrows don't jump out from under the finger.
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

/// Lifetime totals.
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

  String get _work {
    final sessions = lifetime.sessions == 1
        ? '1 session'
        : '${lifetime.sessions} sessions';
    return '$sessions · ${focusLabel(lifetime.focus)}';
  }

  /// Level and plots unlocked go together, so they share a line.
  String get _garden {
    final plots =
        lifetime.plots == 1 ? '1 plot' : '${lifetime.plots} plots';
    return 'Garden level ${lifetime.gardenLevel} · $plots';
  }

  /// Awarded plants are counted separately so the total doesn't overstate the
  /// sessions behind it.
  String get _plants {
    final plants =
        lifetime.plants == 1 ? '1 plant' : '${lifetime.plants} plants';
    if (lifetime.bonusPlants == 0) return plants;
    return lifetime.bonusPlants == 1
        ? '$plants · 1 of them a bonus plant'
        : '$plants · ${lifetime.bonusPlants} of them bonus plants';
  }
}

/// A journal card: handwritten heading, optional note and trailing controls,
/// then content. The first card gets a strip of tape.
class _JournalCard extends StatelessWidget {
  const _JournalCard({
    required this.heading,
    required this.children,
    this.note,
    this.actions = const [],
    this.taped = false,
  });

  final String heading;

  final List<Widget> actions;

  /// Small print under the heading, usually a date range.
  final String? note;

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
                  child: Headline(
                    heading,
                    // Handwritten face; only used here and on plant labels.
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

/// Empty state for a new user, instead of three cards of zeroes.
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
                Headline(
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

/// Shown when the figures can't be read. The sessions aren't gone, they just
/// couldn't be counted.
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

/// Focus time as `5h 20m`, `45m`, `143h`. No seconds; it's read at a glance.
String focusLabel(Duration focus) {
  final hours = focus.inHours;
  final minutes = focus.inMinutes % Duration.minutesPerHour;

  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}
