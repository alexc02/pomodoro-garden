import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_analytics_event_log.dart';
import 'package:pip_garden/src/data/drift_cycle_store.dart';
import 'package:pip_garden/src/data/drift_decor_repository.dart';
import 'package:pip_garden/src/data/drift_garden_reset.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/data/drift_settings_repository.dart';

import '../support/garden_seed.dart';

/// REQ-036's reset, at the table it actually clears.
///
/// The screen and its two confirmations are
/// `test/features/settings/garden_reset_test.dart`. What is under test here is
/// the narrower and more consequential half: which rows go, which rows stay,
/// and that the answer is the same whether the reset is the first one or the
/// third.
void main() {
  late AppDatabase database;
  late DriftGardenReset reset;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
    reset = DriftGardenReset(database);
  });

  Future<int> countOf(String table) async {
    final rows =
        await database.customSelect('SELECT COUNT(*) AS n FROM $table').get();
    return rows.single.read<int>('n');
  }

  test('clears the plants, the sessions, the arrangement and the log',
      () async {
    await seedGarden(database, sessions: 6);
    await DriftDecorRepository(database).save(Decor(
      id: 'bench',
      kind: DecorKind.bench,
      plot: const GardenPlot(2, 1),
      placedAt: DateTime.utc(2026, 8, 26),
    ));
    await DriftAnalyticsEventLog(database).append(
      const AppOpened(daysSinceLastOpen: 1, streakDays: 4),
      at: DateTime.utc(2026, 8, 26),
    );

    await reset.clear();

    expect(await countOf('plants'), 0);
    expect(await countOf('sessions'), 0);
    expect(await countOf('decor'), 0);
    expect(await countOf('analytics_events'), 0);
  });

  test('puts the cycle back at session one (BUG-02)', () async {
    final cycle = DriftCycleStore(database);
    await cycle.save(3);

    await reset.clear();

    expect(await countOf('cycle'), 0);
    expect(await cycle.load(), 0);
  });

  test('leaves the settings row where it is', () async {
    final settings = DriftSettingsRepository(database);
    await settings.save(
      GardenSettings.defaults
          .withSessionLength(const Duration(minutes: 50))
          .withGardenTheme(GardenTheme.tropical)
          .withHaptics(enabled: false)
          .withOnboardingCompleted(),
    );
    await seedGarden(database, sessions: 2);

    await reset.clear();

    final kept = await settings.load();
    expect(kept.sessionLength, const Duration(minutes: 50));
    expect(kept.gardenTheme, GardenTheme.tropical);
    expect(kept.hapticsEnabled, isFalse);
    // The one that would be felt hardest if it went: onboarding coming back
    // would greet a user who has been here for months as a stranger.
    expect(kept.onboardingCompleted, isTrue);
  });

  test('a milestone can be earned again from an empty garden', () async {
    final garden = DriftPlantRepository(database);
    await garden.save(Plant.forMilestone(
      Milestone.ten,
      id: 'awarded',
      plantedAt: DateTime.utc(2026, 8, 1),
      plot: const GardenPlot(0, 0),
    ));
    expect(await garden.awardedMilestones(), {Milestone.ten});

    await reset.clear();

    // Not merely "the row is gone": what the app asks before awarding anything
    // is this question, and the answer has to be the one a first run gives.
    expect(await garden.awardedMilestones(), isEmpty);
    expect(
      Milestone.dueFrom(completedSessions: 10, awarded: const {}),
      [Milestone.ten],
    );
  });

  test('a reset garden takes plants and sessions again', () async {
    await seedGarden(database, sessions: 3);
    await reset.clear();
    await seedGarden(database, sessions: 3);

    expect(await DriftSessionRepository(database).completedSessions(),
        hasLength(3));
    expect(await DriftPlantRepository(database).plants(), hasLength(3));
  });

  test('resetting an empty garden does nothing at all', () async {
    await reset.clear();
    await reset.clear();

    expect(await countOf('plants'), 0);
    expect(await countOf('sessions'), 0);
  });
}
