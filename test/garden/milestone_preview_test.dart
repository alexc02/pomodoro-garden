import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_plant_repository.dart';
import 'package:pomodoro_garden/src/features/garden/garden_screen.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/garden/garden_providers.dart';
import 'package:pomodoro_garden/src/garden/golden_shimmer.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/garden_seed.dart';

/// Ticket 36's debug preview: the garden as though 500 or 1000 sessions had
/// been reached, without writing anything.
void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  Future<GardenLayout> layoutOnScreen(WidgetTester tester) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GardenScreen)),
    );
    return container.read(gardenLayoutProvider.future);
  }

  Future<void> preview(WidgetTester tester, String chip) async {
    await tapTab(tester, AppTab.settings);
    await scrollToSetting(tester, SettingsKeys.milestonePreview);
    await tester.tap(find.text(chip));
    await settle(tester);
    await tapTab(tester, AppTab.garden);
  }

  testWidgets('500 lays the enchanted willow into the garden on screen',
      (tester) async {
    await seedGarden(database, sessions: 3);
    await pumpApp(tester, database: database);

    await preview(tester, '500 · willow');

    final layout = await layoutOnScreen(tester);
    expect(
      layout.bonusPlants.map((plant) => plant.species),
      [PlantSpecies.enchantedWillow],
    );
    expect(GoldenShimmer.earnedBy(layout), isFalse);
  });

  testWidgets('1000 adds the golden garden, and the shimmer is earned',
      (tester) async {
    await seedGarden(database, sessions: 3);
    await pumpApp(tester, database: database);

    await preview(tester, '1000 · golden');

    final layout = await layoutOnScreen(tester);
    expect(layout.bonusPlants, hasLength(2));
    expect(GoldenShimmer.earnedBy(layout), isTrue);
    expect(layout.plants, hasLength(5), reason: 'three grown, two previewed');
  });

  testWidgets('writes nothing, and Off puts the garden back', (tester) async {
    await seedGarden(database, sessions: 3);
    await pumpApp(tester, database: database);

    await preview(tester, '1000 · golden');
    expect(await DriftPlantRepository(database).plants(), hasLength(3));

    await preview(tester, 'Off');
    expect((await layoutOnScreen(tester)).bonusPlants, isEmpty);
  });
}
