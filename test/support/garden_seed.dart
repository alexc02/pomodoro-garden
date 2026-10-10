import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_plant_repository.dart';
import 'package:pomodoro_garden/src/data/drift_session_repository.dart';

import 'app_harness.dart';

/// Writes [sessions] completed sessions and the plant each of them grew.
///
/// Written through the repositories rather than as raw rows, so a garden a test
/// starts with is a garden this app could have grown: the sessions are
/// completed ones, the plants come from `Plant.fromSession`, and each stands in
/// the plot the placement rule would have given it.
///
/// The alternative — running the sessions through the timer — is minutes of
/// pumped frames for a garden of two hundred, and it exercises ticket 02 rather
/// than ticket 07. `test/garden/planting_test.dart` is where the timer really
/// does grow the plant.
Future<void> seedGarden(AppDatabase database, {required int sessions}) async {
  final recorded = DriftSessionRepository(database);
  final garden = DriftPlantRepository(database);
  // Kept alongside rather than asked of the database each time: the app asks
  // once per completed session, and a test seeding two hundred of them in a row
  // would otherwise spend its time on two hundred queries whose answer it
  // already knows.
  final occupied = <GardenPlot>{};

  for (var n = 0; n < sessions; n++) {
    // Oldest first, so the placement order and the planting order agree — which
    // is what a garden grown one session at a time looks like.
    final anchor = testInstant.subtract(Duration(hours: sessions - n));
    final session = FocusSession(
      id: 'seeded-session-$n',
      startedAt: anchor,
      // A spread of lengths, so a seeded garden has every type of plant in it
      // rather than two hundred of the same tulip.
      plannedDuration: Duration(minutes: 10 + (n % 6) * 20),
    ).completedAt(anchor.add(const Duration(minutes: 25)));

    final plot = GardenPlots.nextFree(occupied);
    if (plot != null) occupied.add(plot);

    await recorded.save(session);
    await garden.save(
      Plant.fromSession(session, id: 'seeded-plant-$n', plot: plot),
    );
  }
}
