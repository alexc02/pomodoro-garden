import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'plant_providers.dart';

/// The shelf: every species' spot, and the plants that aren't in the garden.
///
/// Derived from [plantsProvider], so whatever refreshes the garden refreshes
/// this too.
final shelfProvider = FutureProvider<Shelf>(
  (ref) async => Shelf.of(await ref.watch(plantsProvider.future)),
);
