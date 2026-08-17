import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_plant_repository.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';

import 'app_harness.dart';

/// Writes [sessions] completed sessions and their plants through the
/// repositories, placed the way the app would place them. Much faster than
/// running them through the timer.
Future<void> seedGarden(AppDatabase database, {required int sessions}) async {
  final recorded = DriftSessionRepository(database);
  final garden = DriftPlantRepository(database);
  // Tracked locally to avoid a query per session.
  final occupied = <GardenPlot>{};

  for (var n = 0; n < sessions; n++) {
    // Oldest first, so placement order matches planting order.
    final anchor = testInstant.subtract(Duration(hours: sessions - n));
    final session = FocusSession(
      id: 'seeded-session-$n',
      startedAt: anchor,
      // Mixed lengths so every plant type shows up.
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
