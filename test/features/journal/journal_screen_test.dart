import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/design/garden_colors.dart';
import 'package:pip_garden/src/design/page_header.dart';
import 'package:pip_garden/src/design/sky_band_backdrop.dart';
import 'package:pip_garden/src/design/typography.dart';
import 'package:pip_garden/src/features/journal/journal_heatmap.dart';
import 'package:pip_garden/src/features/journal/journal_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';

// Real app, real database, history seeded before launch.
//
// Local time on purpose: the journal is about the user's calendar, so a UTC
// clock would behave differently per machine timezone.
final DateTime _today = DateTime(2026, 8, 11, 9, 41);

/// In the week 9-15 Aug with Sunday week start (default English locale).
const CalendarDay _tuesday = CalendarDay(2026, 8, 11);

void main() {
  late AppDatabase database;
  late DriftSessionRepository sessions;
  late DriftPlantRepository garden;
  late FixedClock clock;

  setUp(() {
    database = AppDatabase.forTesting();
    sessions = DriftSessionRepository(database);
    garden = DriftPlantRepository(database);
    clock = FixedClock(_today.toUtc());
  });

  tearDown(() => database.close());

  /// Taken plots, so seeded gardens fill outwards like a real one.
  final occupied = <GardenPlot>{};

  /// Writes a completed session anchored at [local], plus its plant.
  Future<void> completed(
    DateTime local, {
    Duration length = const Duration(minutes: 25),
    bool grew = true,
  }) async {
    final anchor = local.toUtc();
    final id = 'session-${anchor.microsecondsSinceEpoch}';
    final session = FocusSession(
      id: id,
      startedAt: anchor,
      plannedDuration: length,
    ).completedAt(anchor.add(length));

    await sessions.save(session);
    if (!grew) return;

    final plot = GardenPlots.nextFree(occupied);
    if (plot != null) occupied.add(plot);
    await garden.save(Plant.fromSession(session, id: 'plant-$id', plot: plot));
  }

  /// Opens the app on the journal tab, in a window tall enough to show the
  /// whole page without scrolling.
  Future<void> openJournal(WidgetTester tester) async {
    await pumpApp(
      tester,
      clock: clock,
      database: database,
      surface: const Size(420, 1600),
    );
    await tapTab(tester, AppTab.journal);
  }

  /// All text on screen, including semantics labels.
  List<String> writtenOn(WidgetTester tester) => [
        for (final text in tester.widgetList<Text>(find.byType(Text)))
          text.data ?? '',
        for (final semantics in tester.widgetList<Semantics>(
          find.byType(Semantics),
        ))
          semantics.properties.label ?? '',
      ];

  Color shadeOf(WidgetTester tester, CalendarDay day) {
    final cell = find.byWidgetPredicate(
      (widget) => widget is HeatmapDay && widget.day == day,
    );
    expect(cell, findsOneWidget, reason: 'no cell for $day');

    final box = tester.widget<DecoratedBox>(
      find.descendant(of: cell, matching: find.byType(DecoratedBox)),
    );
    return (box.decoration as BoxDecoration).color!;
  }

  group('the week in review', () {
    testWidgets('shows sessions, time and plants for this week',
        (tester) async {
      final semantics = tester.ensureSemantics();

      // A June session too, so the lifetime card can't satisfy the week check.
      await completed(DateTime(2026, 6, 1, 9));
      await completed(DateTime(2026, 8, 9, 8), length: const Duration(minutes: 25));
      await completed(DateTime(2026, 8, 11, 8), length: const Duration(minutes: 50));
      await completed(DateTime(2026, 8, 11, 14), length: const Duration(minutes: 15));

      await openJournal(tester);

      expect(find.text('This week'), findsOneWidget);
      expect(find.text('3 sessions · 1h 30m'), findsOneWidget);
      // The card merges child semantics, so look inside its label.
      expect(
        find.bySemanticsLabel(RegExp('3 plants grown this week')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('uses the locale week boundary', (tester) async {
      // Sat 8th is last week with a Sunday start; Sun 9th starts this one.
      await completed(DateTime(2026, 8, 8, 20));
      await completed(DateTime(2026, 8, 9, 0, 5));

      await openJournal(tester);

      expect(find.text('1 session · 25m'), findsOneWidget);
      expect(find.text('Aug 9 – Aug 15'), findsOneWidget);
    });

    testWidgets('empty week copy', (tester) async {
      // Some history, but nothing this week.
      await completed(DateTime(2026, 7, 20, 9));

      await openJournal(tester);

      expect(find.text('Nothing planted yet this week.'), findsOneWidget);
    });
  });

  group('the streak', () {
    testWidgets('counts consecutive days', (tester) async {
      for (final back in [0, 1, 2]) {
        await completed(DateTime(2026, 8, 11 - back, 9));
      }

      await openJournal(tester);

      expect(find.text('3 days in a row.'), findsOneWidget);
    });

    testWidgets('holds if today has no session yet', (tester) async {
      // Yesterday and the day before, nothing yet today.
      await completed(DateTime(2026, 8, 10, 9));
      await completed(DateTime(2026, 8, 9, 9));

      await openJournal(tester);

      expect(find.text('2 days in a row.'), findsOneWidget);
    });

    testWidgets('a gap is shown as a rest', (tester) async {
      await completed(DateTime(2026, 8, 9, 9));

      await openJournal(tester);

      expect(find.text('Your garden rested for 2 days.'), findsOneWidget);
    });

    testWidgets('no guilt wording', (tester) async {
      // Long streak then a long gap. Checks every word on the page.
      for (final back in [40, 41, 42, 43, 44]) {
        await completed(DateTime(2026, 8, 11 - back, 9));
      }

      await openJournal(tester);

      const guilt = [
        'broke',
        'broken',
        'fail',
        'missed',
        'lost',
        'streak',
        'again',
        'should',
        "didn't",
        'behind',
      ];
      for (final word in writtenOn(tester)) {
        for (final forbidden in guilt) {
          expect(
            word.toLowerCase(),
            isNot(contains(forbidden)),
            reason: '"$word" should not appear on this screen',
          );
        }
      }
      expect(find.text('Your garden rested for 40 days.'), findsOneWidget);
    });
  });

  group('the month', () {
    testWidgets('one cell per day of the month', (tester) async {
      await completed(DateTime(2026, 8, 11, 9));

      await openJournal(tester);

      expect(find.text('August 2026'), findsOneWidget);
      expect(find.byType(HeatmapDay), findsNWidgets(31));
      expect(
        find.byWidgetPredicate(
          (widget) => widget is HeatmapDay && widget.day.month != 8,
        ),
        findsNothing,
      );
    });

    testWidgets('busier days are greener, empty days soil', (tester) async {
      await completed(DateTime(2026, 8, 3, 9));
      await completed(DateTime(2026, 8, 3, 11));
      await completed(DateTime(2026, 8, 3, 14));
      await completed(DateTime(2026, 8, 5, 9));

      await openJournal(tester);

      final busiest = shadeOf(tester, const CalendarDay(2026, 8, 3));
      final quieter = shadeOf(tester, const CalendarDay(2026, 8, 5));
      final bare = shadeOf(tester, const CalendarDay(2026, 8, 4));

      expect(busiest, isNot(quieter));
      expect(quieter, isNot(bare));
      expect(_greenness(busiest), greaterThan(_greenness(quieter)));
      expect(_greenness(quieter), greaterThan(_greenness(bare)));
    });

    testWidgets('shows days tended', (tester) async {
      await completed(DateTime(2026, 8, 3, 9));
      await completed(DateTime(2026, 8, 3, 11));
      await completed(DateTime(2026, 8, 5, 9));

      await openJournal(tester);

      expect(find.text('2 days tended this month.'), findsOneWidget);
    });

    testWidgets('has one semantics label', (tester) async {
      final semantics = tester.ensureSemantics();

      await completed(DateTime(2026, 8, 3, 9));
      await completed(DateTime(2026, 8, 3, 11));

      await openJournal(tester);

      expect(
        find.bySemanticsLabel(RegExp(
          'A calendar of the month, each day shaded by how much was grown in '
          'it, up to 2 sessions in a day.',
        )),
        findsOneWidget,
      );
      // No per-cell labels.
      expect(find.bySemanticsLabel(RegExp('Aug 4')), findsNothing);
      semantics.dispose();
    });
  });

  group('earlier months', () {
    IconButton arrow(WidgetTester tester, Key key) =>
        tester.widget<IconButton>(find.byKey(key));

    Future<void> step(WidgetTester tester, Key key) async {
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    testWidgets('opens on this month', (tester) async {
      await completed(DateTime(2026, 6, 20, 9));
      await completed(DateTime(2026, 8, 3, 9));

      await openJournal(tester);

      expect(find.text('August 2026'), findsOneWidget);
      expect(arrow(tester, JournalKeys.nextMonth).onPressed, isNull);
      expect(arrow(tester, JournalKeys.previousMonth).onPressed, isNotNull);
    });

    testWidgets('steps back month by month', (tester) async {
      await completed(DateTime(2026, 6, 20, 9));
      await completed(DateTime(2026, 8, 3, 9));

      await openJournal(tester);
      await step(tester, JournalKeys.previousMonth);

      expect(find.text('July 2026'), findsOneWidget);
      expect(find.byType(HeatmapDay), findsNWidgets(31));
      expect(find.text('A month of bare soil.'), findsOneWidget);

      await step(tester, JournalKeys.previousMonth);

      expect(find.text('June 2026'), findsOneWidget);
      expect(find.byType(HeatmapDay), findsNWidgets(30));
      expect(find.text('One day tended that month.'), findsOneWidget);
      expect(
        shadeOf(tester, const CalendarDay(2026, 6, 20)),
        isNot(shadeOf(tester, const CalendarDay(2026, 6, 21))),
      );
    });

    testWidgets('stops at the month of the first session', (tester) async {
      await completed(DateTime(2026, 7, 2, 9));

      await openJournal(tester);
      await step(tester, JournalKeys.previousMonth);

      expect(find.text('July 2026'), findsOneWidget);
      expect(arrow(tester, JournalKeys.previousMonth).onPressed, isNull);
    });

    testWidgets('steps forward to this month', (tester) async {
      await completed(DateTime(2026, 7, 2, 9));
      await completed(DateTime(2026, 8, 3, 9));

      await openJournal(tester);
      await step(tester, JournalKeys.previousMonth);
      await step(tester, JournalKeys.nextMonth);

      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('One day tended this month.'), findsOneWidget);
    });

    testWidgets("can't go back with only this month's sessions",
        (tester) async {
      await completed(DateTime(2026, 8, 3, 9));

      await openJournal(tester);

      expect(arrow(tester, JournalKeys.previousMonth).onPressed, isNull);
    });

    testWidgets('week and lifetime stay on today', (tester) async {
      await completed(DateTime(2026, 6, 20, 9));
      await completed(DateTime(2026, 8, 10, 9));

      await openJournal(tester);
      final before = writtenOn(tester)
          .where((line) => line.contains('this week') || line.contains('·'))
          .toList();

      await step(tester, JournalKeys.previousMonth);

      expect(
        writtenOn(tester)
            .where((line) => line.contains('this week') || line.contains('·'))
            .toList(),
        before,
      );
    });
  });

  group('the lifetime', () {
    testWidgets('shows sessions, hours, plants, level and plots',
        (tester) async {
      // 12 sessions over two months: one unlock, so level 2.
      for (var n = 0; n < 12; n++) {
        await completed(
          DateTime(2026, 7, 1, 9).add(Duration(days: n)),
          length: const Duration(hours: 1),
        );
      }

      await openJournal(tester);

      expect(find.text('Lifetime'), findsOneWidget);
      expect(find.text('12 sessions · 12h'), findsOneWidget);
      // 13 plants for 12 sessions: the 10th earned a bonus plant.
      expect(find.text('13 plants · 1 of them a bonus plant'), findsOneWidget);
      expect(find.text('Garden level 2 · 16 plots'), findsOneWidget);
    });

    testWidgets('counts bonus plants separately', (tester) async {
      await completed(DateTime(2026, 8, 4, 9));
      await garden.save(Plant.forMilestone(
        Milestone.ten,
        id: 'awarded',
        plantedAt: DateTime(2026, 8, 4, 10).toUtc(),
        plot: const GardenPlot(5, 5),
      ));

      await openJournal(tester);

      expect(find.text('2 plants · 1 of them a bonus plant'), findsOneWidget);
      // The bonus plant doesn't count as a session.
      expect(find.text('1 session · 25m'), findsOneWidget);
    });
  });

  group('empty journal', () {
    testWidgets('shows an invite instead of zeroes', (tester) async {
      await openJournal(tester);

      expect(find.text('Your journal'), findsOneWidget);
      expect(
        find.text('Nothing pressed between these pages yet.'),
        findsOneWidget,
      );
      expect(find.text('This week'), findsNothing);
      expect(find.text('Lifetime'), findsNothing);
      expect(find.byType(HeatmapDay), findsNothing);
      for (final word in writtenOn(tester)) {
        expect(word, isNot(contains('0 ')));
      }
    });
  });

  group('the page itself', () {
    test('header shows what has grown', () {
      expect(journalHeadline(1), 'One plant, pressed.');
      expect(journalHeadline(13), 'Thirteen plants, pressed.');
      expect(journalHeadline(42), 'Forty-two plants, pressed.');
      expect(journalHeadline(142), '142 plants, pressed.');
    });

    testWidgets('has no app bar', (tester) async {
      await completed(DateTime(2026, 8, 11, 9));

      await openJournal(tester);

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Kept since August 2026'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PageHeader),
          matching: find.text('One plant, pressed.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('paper background and display font headings', (tester) async {
      await completed(DateTime(2026, 8, 11, 9));

      await openJournal(tester);

      expect(find.byType(SkyBandBackdrop), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);

      final headings = tester
          .widgetList<Text>(find.byType(Text))
          .where((text) =>
              text.style?.fontFamily == GardenTypography.displayFontFamily)
          .map((text) => text.data);
      expect(
        headings,
        containsAll(<String>['This week', 'August 2026', 'Lifetime']),
      );
    });

    testWidgets('is one scrollable page', (tester) async {
      await completed(DateTime(2026, 8, 11, 9));

      await openJournal(tester);

      expect(
        find.descendant(
          of: find.byType(JournalScreen),
          matching: find.byType(Scrollable),
        ),
        findsOneWidget,
      );
    });

    testWidgets('works in dark mode', (tester) async {
      useDarkMode(tester);
      await completed(DateTime(2026, 8, 11, 9));

      await openJournal(tester);

      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Garden level 1 · 12 plots'), findsOneWidget);

      // Bare-day soil is mixed against the page colour, so it must change in
      // dark mode.
      final context = tester.element(find.byType(JournalHeatmap));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(
        shadeOf(tester, const CalendarDay(2026, 8, 20)),
        heatmapShade(
          sessions: 0,
          busiestDay: 1,
          colors: GardenColors.of(context),
          paper: Theme.of(context).scaffoldBackgroundColor,
        ),
      );
    });
  });

  group('updates', () {
    testWidgets('picks up a session finished while open', (tester) async {
      await pumpApp(tester, clock: clock, database: database);

      await tapTab(tester, AppTab.journal);
      expect(find.text('Your journal'), findsOneWidget);

      await startSession(tester);
      await advance(tester, clock, const Duration(minutes: 25));
      await settle(tester);

      await tapTab(tester, AppTab.journal);
      expect(find.text('1 session · 25m'), findsOneWidget);
      expect(find.text('1 day in a row.'), findsOneWidget);
      expect(shadeOf(tester, _tuesday), isNot(shadeOf(tester, const CalendarDay(2026, 8, 12))));
    });
  });
}

/// Green channel minus the average of the other two, for ordering shades.
double _greenness(Color colour) => colour.g - (colour.r + colour.b) / 2;
