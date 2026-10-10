import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../data/database_providers.dart';
import 'art_providers.dart';
import 'placeholder_plant_sprites.dart';
import 'plant_sprite.dart';

/// Every plant in the garden, most recently planted first.
///
/// Invalidated by `SessionController` when a session completes, so anything
/// showing the garden refreshes on its own. Read from the database rather than
/// held in memory for the same reason the session count is: the garden is what
/// is on disk, and it has to look the same after a relaunch.
final plantsProvider = FutureProvider<List<Plant>>(
  (ref) => ref.watch(plantRepositoryProvider).plants(),
);

/// Where every plant on screen gets its picture.
///
/// A provider rather than a constant so ticket 23 can swap the whole art set by
/// overriding one line, and so a test can supply a registry it can assert
/// against. Nothing else in the app is allowed to name a plant image; see
/// `test/garden/sprites_are_the_only_art_test.dart`.
///
/// **This is the one line ticket 04 promised ticket 23 would change**, and it
/// is now a choice between two registries rather than one constant: the
/// decoded art if this build ships any, and ticket 04's placeholder shapes if
/// it does not. `PlaceholderPlantSpriteRegistry` stays because the fallback is
/// real — an art set is a delivery from outside this repository and a build can
/// legitimately be made before it arrives.
///
/// Read synchronously off an already-resolved future, which is what `ArtGate`
/// is for: below the gate the bundle has loaded, so nothing here has a loading
/// branch and no plant is ever asked to draw itself before its picture exists.
final plantSpriteRegistryProvider = Provider<PlantSpriteRegistry>((ref) {
  final art = ref.watch(artBundleProvider).value;
  return art?.plants ?? const PlaceholderPlantSpriteRegistry();
});
