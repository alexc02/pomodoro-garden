import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../data/database_providers.dart';
import '../time/clock_provider.dart';

/// The day the app is on, where the device is.
///
/// A provider rather than a call to the clock at the point of use, for the same
/// two reasons `seasonProvider` is one: a test can move it without moving the
/// machine running the suite, and it re-reads itself when the day underneath it
/// can have changed. A journal left open across midnight turns over into the
/// new day rather than showing yesterday's week until something else happens.
///
/// This is the second place in the app that calls `toLocal()`, and — like the
/// season — it is the presentation edge ADR 0001's UTC rule points at. See
/// `docs/adr/0012-a-day-in-the-journal-is-the-day-a-session-was-anchored.md`.
final todayProvider = NotifierProvider<Today, CalendarDay>(Today.new);

/// Reads the local date off the clock, and looks again when it can have moved.
class Today extends Notifier<CalendarDay> {
  Timer? _nextLook;

  /// The longest this will go without re-reading the clock.
  ///
  /// Midnight is the boundary it is aimed at, and the hourly ceiling catches
  /// the two things that can move a boundary underneath a timer: the user
  /// correcting the device's date, and the device crossing into another time
  /// zone. Same reasoning, and the same cost, as `GardenSeason.longestWait` —
  /// a foreground timer, disposed with the provider.
  static const Duration longestWait = Duration(hours: 1);

  @override
  CalendarDay build() {
    ref.onDispose(_stopLooking);

    final now = ref.watch(clockProvider).now().toLocal();
    final today = CalendarDay.of(now);
    _lookAgainBefore(today.tomorrow.startsAt.difference(now));

    return today;
  }

  void _lookAgainBefore(Duration untilMidnight) {
    _stopLooking();
    final wait = untilMidnight < longestWait ? untilMidnight : longestWait;
    // Rebuilding is the whole of the work, and Riverpod tells nobody when the
    // day it arrives at is the one already on screen — which is every look
    // but one a day.
    _nextLook = Timer(wait, ref.invalidateSelf);
  }

  void _stopLooking() {
    _nextLook?.cancel();
    _nextLook = null;
  }
}

/// The botanical journal, for a locale whose week starts on [firstDayOfWeek].
///
/// A family keyed by the first day of the week because that is a *locale's*
/// answer and not the app's — `MaterialLocalizations` knows it and this
/// provider cannot reach one, so the screen passes it in. Two locales open on
/// the same history are two different weeks and therefore two different reads,
/// which is exactly what a family is.
///
/// Six queries, run together rather than in turn: they touch two tables and
/// none of them depends on another's answer, so the journal costs one round
/// trip rather than six. Everything they come back with is folded into the
/// domain's own values — nothing on this page is assembled by a widget.
///
/// It is invalidated by the two things that can change what is on it: a session
/// completing (`SessionController`) and a milestone being awarded
/// (`MilestoneAwards`). The journal tab is kept alive by the shell's
/// `IndexedStack`, so without that it would still be showing the figures it was
/// built with when the user first opened it.
final journalProvider = FutureProvider.family<Journal, int>(
  (ref, firstDayOfWeek) async {
    final repository = ref.watch(journalRepositoryProvider);
    final today = ref.watch(todayProvider);
    final week = DayRange.week(today, firstDayOfWeek: firstDayOfWeek);
    final month = DayRange.month(today);

    final (
      weekSessions,
      weekPlants,
      monthSessions,
      activeDays,
      everySession,
      everyPlant,
    ) = await (
      repository.sessionsIn(week),
      repository.plantsIn(week),
      repository.sessionsByDay(month),
      repository.daysWithSessions(),
      repository.sessionsEver(),
      repository.plantsEver(),
    ).wait;

    return Journal(
      today: today,
      week: JournalWeek.of(
        week: week,
        sessions: weekSessions,
        plants: weekPlants,
      ),
      month: JournalMonth.of(month: month, sessionsByDay: monthSessions),
      lifetime: JournalLifetime.of(
        sessions: everySession,
        plants: everyPlant,
      ),
      streak: Streak.from(activeDays: activeDays, today: today),
      firstTended: activeDays.isEmpty
          ? null
          : activeDays.reduce((a, b) => a.isBefore(b) ? a : b),
    );
  },
);

/// One whole month of the heatmap, for REQ-027's arrows: the month that
/// [firstOfMonth] begins.
///
/// The current month comes with [journalProvider]'s single read; this is only
/// asked for once the user steps back from it. Invalidated alongside
/// [journalProvider] wherever sessions change, because a session anchored late
/// on the last day of a month belongs to that month even if it finished in the
/// next one.
final journalMonthProvider = FutureProvider.family<JournalMonth, CalendarDay>(
  (ref, firstOfMonth) async {
    final month = DayRange.month(firstOfMonth);
    return JournalMonth.of(
      month: month,
      sessionsByDay:
          await ref.watch(journalRepositoryProvider).sessionsByDay(month),
    );
  },
);
