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

/// The journal, driven the way a user reaches it: the real app, the real
/// database, and a history written into it before the app opens.
///
/// The day everything here is read on. Built from a *local* time on purpose —
/// the journal's whole subject is the user's own calendar, so a suite that
/// pinned the clock to a UTC instant would ask a different question on a
/// machine in Auckland than on one in Chicago.
final DateTime _today = DateTime(2026, 8, 11, 9, 41);

/// Tuesday 11 August 2026 sits in the week 9–15 August when the week starts on
/// Sunday, which is what the default English locale says.
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

  /// The plots already taken, so a seeded garden fills outwards the way a real
  /// one does.
  final occupied = <GardenPlot>{};

  /// Writes a completed session anchored at [local], and the plant it grew.
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

  /// Opens the app on the journal tab.
  ///
  /// On a window tall enough to hold the whole page. The journal is one
  /// scrollable page by requirement, and a test that had to scroll to the
  /// lifetime card before asserting on it would be asserting on the scroll
  /// rather than on the card — `is one scrollable page` is where that is
  /// checked, once.
  Future<void> openJournal(WidgetTester tester) async {
    await pumpApp(
      tester,
      clock: clock,
      database: database,
      surface: const Size(420, 1600),
    );
    await tapTab(tester, AppTab.journal);
  }

  /// Every word on screen, from the widgets and from the labels a screen reader
  /// would read out.
  List<String> writtenOn(WidgetTester tester) => [
        for (final text in tester.widgetList<Text>(find.byType(Text)))
          text.data ?? '',
        for (final semantics in tester.widgetList<Semantics>(
          find.byType(Semantics),
        ))
          semantics.properties.label ?? '',
      ];

  /// The colour one day of the heatmap is drawn in.
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
    testWidgets('REQ-026: the sessions, the time and the plants of this week',
        (tester) async {
      final semantics = tester.ensureSemantics();

      // A session from June as well, so the week's line cannot be satisfied by
      // the lifetime card underneath it saying the same thing.
      await completed(DateTime(2026, 6, 1, 9));
      await completed(DateTime(2026, 8, 9, 8), length: const Duration(minutes: 25));
      await completed(DateTime(2026, 8, 11, 8), length: const Duration(minutes: 50));
      await completed(DateTime(2026, 8, 11, 14), length: const Duration(minutes: 15));

      await openJournal(tester);

      expect(find.text('This week'), findsOneWidget);
      expect(find.text('3 sessions · 1h 30m'), findsOneWidget);
      // The plants themselves, drawn rather than counted. A card merges the
      // semantics of everything inside it, so the label is looked for *in* the
      // card's own sentence rather than as a node of its own.
      expect(
        find.bySemanticsLabel(RegExp('3 plants grown this week')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('holds this week alone, on the locale\'s own week boundary',
        (tester) async {
      // Saturday the 8th is the week before, when a week starts on Sunday;
      // Sunday the 9th is the first day of this one.
      await completed(DateTime(2026, 8, 8, 20));
      await completed(DateTime(2026, 8, 9, 0, 5));

      await openJournal(tester);

      expect(find.text('1 session · 25m'), findsOneWidget);
      expect(find.text('Aug 9 – Aug 15'), findsOneWidget);
    });

    testWidgets('says a quiet week is a beginning, not a shortfall',
        (tester) async {
      // A history, but nothing in the week being shown.
      await completed(DateTime(2026, 7, 20, 9));

      await openJournal(tester);

      expect(find.text('Nothing planted yet this week.'), findsOneWidget);
    });
  });

  group('the streak', () {
    testWidgets('REQ-029: counts the days in a row', (tester) async {
      for (final back in [0, 1, 2]) {
        await completed(DateTime(2026, 8, 11 - back, 9));
      }

      await openJournal(tester);

      expect(find.text('3 days in a row.'), findsOneWidget);
    });

    testWidgets('stands on a day the user has not sat down to yet',
        (tester) async {
      // Yesterday and the day before, nothing today. Today is not over.
      await completed(DateTime(2026, 8, 10, 9));
      await completed(DateTime(2026, 8, 9, 9));

      await openJournal(tester);

      expect(find.text('2 days in a row.'), findsOneWidget);
    });

    testWidgets('REQ-029: a break is a rest, in the requirement\'s own words',
        (tester) async {
      await completed(DateTime(2026, 8, 9, 9));

      await openJournal(tester);

      expect(find.text('Your garden rested for 2 days.'), findsOneWidget);
    });

    testWidgets('there is no guilt anywhere on the page', (tester) async {
      // The screen at its most vulnerable moment: a long streak, then a long
      // gap. Every word on it is asserted, not just the streak's own line.
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
            reason: 'REQ-029: "$word" is not how this screen talks.',
          );
        }
      }
      expect(find.text('Your garden rested for 40 days.'), findsOneWidget);
    });
  });

  group('the month', () {
    testWidgets('REQ-027: a cell for every day of the month, and no more',
        (tester) async {
      await completed(DateTime(2026, 8, 11, 9));

      await openJournal(tester);

      expect(find.text('August 2026'), findsOneWidget);
      expect(find.byType(HeatmapDay), findsNWidgets(31));
      // July and September are not on this page.
      expect(
        find.byWidgetPredicate(
          (widget) => widget is HeatmapDay && widget.day.month != 8,
        ),
        findsNothing,
      );
    });

    testWidgets('REQ-027: a busier day is greener, and an empty one is soil',
        (tester) async {
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
      // Green is what more sessions means, so the greener of the two days is
      // the one with three in it.
      expect(_greenness(busiest), greaterThan(_greenness(quieter)));
      expect(_greenness(quieter), greaterThan(_greenness(bare)));
    });

    testWidgets('says how many days were tended, and nothing about the rest',
        (tester) async {
      await completed(DateTime(2026, 8, 3, 9));
      await completed(DateTime(2026, 8, 3, 11));
      await completed(DateTime(2026, 8, 5, 9));

      await openJournal(tester);

      expect(find.text('2 days tended this month.'), findsOneWidget);
    });

    testWidgets('is read out as a sentence rather than as thirty-one cells',
        (tester) async {
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
      // And not thirty-one dates in a row, which is what a label per cell
      // would have made of a quiet month.
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

    testWidgets('opens on this month, with nowhere further forward to go',
        (tester) async {
      await completed(DateTime(2026, 6, 20, 9));
      await completed(DateTime(2026, 8, 3, 9));

      await openJournal(tester);

      expect(find.text('August 2026'), findsOneWidget);
      expect(arrow(tester, JournalKeys.nextMonth).onPressed, isNull);
      expect(arrow(tester, JournalKeys.previousMonth).onPressed, isNotNull);
    });

    testWidgets('steps back month by month, bare months included',
        (tester) async {
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

    testWidgets('comes forward again to this month and its own words',
        (tester) async {
      await completed(DateTime(2026, 7, 2, 9));
      await completed(DateTime(2026, 8, 3, 9));

      await openJournal(tester);
      await step(tester, JournalKeys.previousMonth);
      await step(tester, JournalKeys.nextMonth);

      expect(find.text('August 2026'), findsOneWidget);
      expect(find.text('One day tended this month.'), findsOneWidget);
    });

    testWidgets('a user with sessions only this month cannot go back',
        (tester) async {
      await completed(DateTime(2026, 8, 3, 9));

      await openJournal(tester);

      expect(arrow(tester, JournalKeys.previousMonth).onPressed, isNull);
    });

    testWidgets('the week and the lifetime stay on today', (tester) async {
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
    testWidgets('REQ-028: sessions, hours, plants, level and plots',
        (tester) async {
      // Twelve sessions across two months: one unlock earned, so level two.
      for (var n = 0; n < 12; n++) {
        await completed(
          DateTime(2026, 7, 1, 9).add(Duration(days: n)),
          length: const Duration(hours: 1),
        );
      }

      await openJournal(tester);

      expect(find.text('Lifetime'), findsOneWidget);
      expect(find.text('12 sessions · 12h'), findsOneWidget);
      // Thirteen plants for twelve sessions: the tenth earned REQ-021's first
      // award, and the journal counts it apart rather than into the work.
      expect(find.text('13 plants · 1 of them a bonus plant'), findsOneWidget);
      expect(find.text('Garden level 2 · 16 plots'), findsOneWidget);
    });

    testWidgets('REQ-028: counts the awarded plants out of the total',
        (tester) async {
      await completed(DateTime(2026, 8, 4, 9));
      await garden.save(Plant.forMilestone(
        Milestone.ten,
        id: 'awarded',
        plantedAt: DateTime(2026, 8, 4, 10).toUtc(),
        plot: const GardenPlot(5, 5),
      ));

      await openJournal(tester);

      expect(find.text('2 plants · 1 of them a bonus plant'), findsOneWidget);
      // And the award is not counted as work: one session, one plant grown.
      expect(find.text('1 session · 25m'), findsOneWidget);
    });
  });

  group('a journal with nothing in it', () {
    testWidgets('invites a new user rather than showing them zeroes',
        (tester) async {
      await openJournal(tester);

      expect(find.text('Your journal'), findsOneWidget);
      expect(
        find.text('Nothing pressed between these pages yet.'),
        findsOneWidget,
      );
      // None of the three cards, and so none of their zeroes.
      expect(find.text('This week'), findsNothing);
      expect(find.text('Lifetime'), findsNothing);
      expect(find.byType(HeatmapDay), findsNothing);
      for (final word in writtenOn(tester)) {
        expect(word, isNot(contains('0 ')));
      }
    });
  });

  group('the page itself', () {
    test('is headed with what has been grown, in words', () {
      expect(journalHeadline(1), 'One plant, pressed.');
      expect(journalHeadline(13), 'Thirteen plants, pressed.');
      expect(journalHeadline(42), 'Forty-two plants, pressed.');
      expect(journalHeadline(142), '142 plants, pressed.');
    });

    testWidgets('PRD v2.3: no app bar; the header says it instead',
        (tester) async {
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

    testWidgets('REQ-025: paper, and headings in the display face',
        (tester) async {
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

    testWidgets('REQ-025: is one scrollable page', (tester) async {
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

    testWidgets('reads in dark mode as well as in light', (tester) async {
      useDarkMode(tester);
      await completed(DateTime(2026, 8, 11, 9));

      await openJournal(tester);

      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Garden level 1 · 12 plots'), findsOneWidget);

      // The soil a bare day is drawn in is mixed against the page it is on, so
      // in dark mode it is mixed against the dark one. A cell whose colour had
      // been fixed at the light palette would fail this.
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

  group('what the journal notices', () {
    testWidgets('a session finished while the app is open', (tester) async {
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

/// How green a colour is, as the heatmap means it: the green channel against
/// the other two.
///
/// A single number so two shades can be ordered. The ramp runs from soil to
/// foliage, so "more sessions" is "further towards green" and nothing else.
double _greenness(Color colour) => colour.g - (colour.r + colour.b) / 2;
