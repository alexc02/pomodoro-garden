import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../data/database_providers.dart';
import 'art_providers.dart';
import 'placeholder_plant_sprites.dart';
import 'plant_sprite.dart';

/// Every plant in the garden, most recently planted first.
///
/// `SessionController` invalidates this when a session completes.
final plantsProvider = FutureProvider<List<Plant>>(
  (ref) => ref.watch(plantRepositoryProvider).plants(),
);

/// Where every plant on screen gets its picture: the decoded art if the build
/// ships any, otherwise the placeholder shapes.
///
/// Nothing else may name a plant image (see
/// `test/garden/sprites_are_the_only_art_test.dart`). Reading `.value` is safe
/// because `ArtGate` holds the app until the bundle has resolved.
final plantSpriteRegistryProvider = Provider<PlantSpriteRegistry>((ref) {
  final art = ref.watch(artBundleProvider).value;
  return art?.plants ?? const PlaceholderPlantSpriteRegistry();
});
