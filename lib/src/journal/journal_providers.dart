import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../data/database_providers.dart';
import '../time/clock_provider.dart';

/// Today's local date. A provider (like `seasonProvider`) so tests can move it
/// and so it rolls over at midnight on its own.
///
/// One of the few places that calls `toLocal()`. A session belongs to the
/// local day it started on.
final todayProvider = NotifierProvider<Today, CalendarDay>(Today.new);

class Today extends Notifier<CalendarDay> {
  Timer? _nextLook;

  /// Re-check at least hourly, to catch date or timezone changes that would
  /// make the midnight timer wrong. Same as `GardenSeason.longestWait`.
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
    // Riverpod won't notify if the rebuilt day is unchanged.
    _nextLook = Timer(wait, ref.invalidateSelf);
  }

  void _stopLooking() {
    _nextLook?.cancel();
    _nextLook = null;
  }
}

/// The journal. Keyed by [firstDayOfWeek] because that comes from the
/// locale (`MaterialLocalizations`), which only the screen can read.
///
/// The six queries are independent, so they run in parallel. Invalidated by
/// `SessionController` and `MilestoneAwards`; the tab stays alive in the
/// `IndexedStack`, so it would go stale otherwise.
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

/// A past month of the heatmap, when the user pages back. The current month
/// comes from [journalProvider]. Invalidate alongside it.
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
