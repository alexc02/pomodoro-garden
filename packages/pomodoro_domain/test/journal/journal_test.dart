import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

const _today = CalendarDay(2026, 8, 11);

final DayRange _week = DayRange.week(_today, firstDayOfWeek: DateTime.monday);
final DayRange _month = DayRange.month(_today);

/// A plant a session grew on [day].
Plant _grown(int n, {CalendarDay? day}) => Plant(
      id: 'plant-$n',
      sessionId: 'session-$n',
      type: PlantType.flower,
      species: PlantSpecies.tulip,
      stage: GrowthStage.mature,
      plantedAt: (day ?? _today).startsAt.toUtc(),
      sessionDuration: const Duration(minutes: 25),
    );

/// A plant a milestone awarded on [_today].
Plant _awarded(Milestone milestone) => Plant.forMilestone(
      milestone,
      id: 'bonus-${milestone.sessions}',
      plantedAt: _today.startsAt.toUtc(),
    );

void main() {
  group('the week in review', () {
    test('is what the week\'s sessions came to', () {
      final week = JournalWeek.of(
        week: _week,
        sessions: const SessionTally(
          sessions: 12,
          focus: Duration(hours: 5, minutes: 20),
        ),
        plants: [_grown(1), _grown(2)],
      );

      expect(week.sessions, 12);
      expect(week.focus, const Duration(hours: 5, minutes: 20));
      expect(week.plants, hasLength(2));
      expect(week.plantsGrown, 2);
      expect(week.range, _week);
    });

    test('counts the plants sessions grew, and not the ones awarded', () {
      final week = JournalWeek.of(
        week: _week,
        sessions: const SessionTally(sessions: 3, focus: Duration(minutes: 75)),
        plants: [_grown(1), _awarded(Milestone.ten), _grown(2), _grown(3)],
      );

      expect(week.plantsGrown, 3);
      expect(week.plants.every((plant) => !plant.isBonus), isTrue);
    });

    test('is a week with nothing in it, for a user who has done nothing', () {
      final week = JournalWeek.of(
        week: _week,
        sessions: SessionTally.none,
        plants: const [],
      );

      expect(week.sessions, 0);
      expect(week.focus, Duration.zero);
      expect(week.plantsGrown, 0);
    });
  });

  group('the month of days', () {
    test('answers how many sessions a day had', () {
      final month = JournalMonth.of(
        month: _month,
        sessionsByDay: {
          const CalendarDay(2026, 8, 3): 2,
          const CalendarDay(2026, 8, 11): 5,
        },
      );

      expect(month.sessionsOn(const CalendarDay(2026, 8, 3)), 2);
      expect(month.sessionsOn(const CalendarDay(2026, 8, 11)), 5);
      expect(month.sessionsOn(const CalendarDay(2026, 8, 4)), 0);
      expect(month.sessionsOn(const CalendarDay(2026, 7, 4)), 0);
    });

    test('knows its busiest day, which is what the shading is scaled to', () {
      final month = JournalMonth.of(
        month: _month,
        sessionsByDay: {
          const CalendarDay(2026, 8, 3): 2,
          const CalendarDay(2026, 8, 11): 5,
          const CalendarDay(2026, 8, 12): 1,
        },
      );

      expect(month.busiestDay, 5);
      expect(month.sessions, 8);
      expect(month.daysTended, 3);
    });

    test('has a busiest day of zero when nothing was done in it', () {
      final month = JournalMonth.of(month: _month, sessionsByDay: const {});

      expect(month.busiestDay, 0);
      expect(month.sessions, 0);
      expect(month.daysTended, 0);
    });

    test('lists every day in the month, empty ones included', () {
      final month = JournalMonth.of(
        month: _month,
        sessionsByDay: {const CalendarDay(2026, 8, 11): 5},
      );

      expect(month.range.eachDay, hasLength(31));
    });
  });

  group('the lifetime', () {
    test('is every session, every hour and every plant', () {
      final lifetime = JournalLifetime.of(
        sessions: const SessionTally(sessions: 342, focus: Duration(hours: 143)),
        plants: const PlantTally(plants: 349, bonusPlants: 7),
      );

      expect(lifetime.sessions, 342);
      expect(lifetime.focus, const Duration(hours: 143));
      expect(lifetime.plants, 349);
      expect(lifetime.bonusPlants, 7);
    });

    test('reads the garden level off the session count', () {
      final lifetime = JournalLifetime.of(
        sessions: const SessionTally(sessions: 100, focus: Duration(hours: 41)),
        plants: const PlantTally(plants: 100, bonusPlants: 2),
      );

      expect(lifetime.gardenLevel, GardenPlots.levelAfter(100));
    });

    test('has the unlocked plots while the plants fit in them', () {
      final lifetime = JournalLifetime.of(
        sessions: const SessionTally(sessions: 10, focus: Duration(hours: 4)),
        plants: const PlantTally(plants: 11, bonusPlants: 1),
      );

      expect(lifetime.plots, GardenPlots.unlockedAfter(10));
      expect(lifetime.plots, 16);
    });

    test('has a plot per plant once they outgrow the unlocks', () {
      // Same rule as GardenLayout: the unlocked count is a floor.
      final lifetime = JournalLifetime.of(
        sessions: const SessionTally(sessions: 100, focus: Duration(hours: 41)),
        plants: const PlantTally(plants: 104, bonusPlants: 4),
      );

      expect(GardenPlots.unlockedAfter(100), 52);
      expect(lifetime.plots, 104);
    });

    test('never has more plots than the garden can hold', () {
      final lifetime = JournalLifetime.of(
        sessions: const SessionTally(sessions: 300, focus: Duration(hours: 125)),
        plants: const PlantTally(plants: 305, bonusPlants: 5),
      );

      expect(lifetime.plots, GardenPlots.maximum);
    });
  });

  group('the journal as a whole', () {
    Journal journalOf({required int lifetimeSessions, required int plants}) =>
        Journal(
          today: _today,
          week: JournalWeek.of(
            week: _week,
            sessions: SessionTally.none,
            plants: const [],
          ),
          month: JournalMonth.of(month: _month, sessionsByDay: const {}),
          lifetime: JournalLifetime.of(
            sessions: SessionTally(
              sessions: lifetimeSessions,
              focus: Duration.zero,
            ),
            plants: PlantTally(plants: plants, bonusPlants: 0),
          ),
          streak: Streak.none,
        );

    test('is empty for a user who has never finished a session', () {
      expect(journalOf(lifetimeSessions: 0, plants: 0).isEmpty, isTrue);
    });

    test('is not empty once anything at all has been grown', () {
      expect(journalOf(lifetimeSessions: 1, plants: 1).isEmpty, isFalse);
      // Can't happen in practice (plant but no sessions), but don't call it
      // empty.
      expect(journalOf(lifetimeSessions: 0, plants: 1).isEmpty, isFalse);
    });
  });
}
