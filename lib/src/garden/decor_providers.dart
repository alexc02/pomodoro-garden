import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../analytics/analytics_providers.dart';
import '../data/database_providers.dart';
import '../feedback/feedback_providers.dart';
import '../session/session_providers.dart';
import '../settings/settings_providers.dart';
import '../time/clock_provider.dart';
import 'art_providers.dart';
import 'decor_sprite.dart';
import 'placeholder_decor_sprites.dart';
import 'plant_providers.dart';

/// Every object in the garden, in the order it was placed.
///
/// Invalidated by [GardenArranger] and by `SessionController` (a completed
/// session can occasionally displace an item).
final decorProvider = FutureProvider<List<Decor>>(
  (ref) => ref.watch(decorRepositoryProvider).decor(),
);

/// Where every decor object on screen gets its picture: the decoded art if
/// the build ships any, otherwise the placeholders. Same deal as
/// `plantSpriteRegistryProvider`.
final decorSpriteRegistryProvider = Provider<DecorSpriteRegistry>(
  (ref) =>
      ref.watch(artBundleProvider).value?.decor ??
      const PlaceholderDecorSpriteRegistry(),
);

/// What the user is in the middle of doing to their arrangement.
///
/// There's no "object armed, waiting for a plot" state on purpose: the picker
/// opens for a plot already tapped, so nothing can be left armed.
sealed class Arranging {
  const Arranging();
}

/// Default: taps open plant cards and nothing moves.
final class NotArranging extends Arranging {
  const NotArranging();
}

/// Arranging, with nothing in hand: a tap on empty soil opens the picker and a
/// tap on a plant or an object picks it up.
final class Choosing extends Arranging {
  const Choosing();
}

/// Something the user has picked up and not yet put anywhere. It's still in
/// [plot] until then; it's only drawn as lifted.
sealed class Holding extends Arranging {
  const Holding();

  /// Where the held thing stands.
  GardenPlot get plot;

  /// False if the garden has changed since it was picked up (a milestone
  /// award took the plot, say). A stale hold moves nothing.
  bool standsIn(GardenLayout garden);
}

/// A plant in hand. Always one in the garden; shelved plants come back
/// through the picker or the shelf instead.
final class HoldingPlant extends Holding {
  const HoldingPlant(this.plant, this.plot);

  final Plant plant;

  @override
  final GardenPlot plot;

  @override
  bool standsIn(GardenLayout garden) => garden.plantIn(plot)?.id == plant.id;
}

/// A decor object in hand. Unlike a plant, it can be removed altogether.
final class HoldingDecor extends Holding {
  const HoldingDecor(this.decor);

  final Decor decor;

  @override
  GardenPlot get plot => decor.plot;

  @override
  bool standsIn(GardenLayout garden) => garden.decorIn(plot)?.id == decor.id;
}

/// True while a session is running or paused. Its plant hasn't been placed
/// yet, so the garden can't be arranged and nothing comes off the shelf
/// until it ends. By the break the plant is already in.
bool sessionHoldsTheGarden(SessionPhase phase) =>
    phase == SessionPhase.running || phase == SessionPhase.paused;

/// Moves plants and decor, places and removes decor, takes plants to the
/// shelf and back, and tracks what the user is halfway through.
final gardenArrangerProvider =
    NotifierProvider<GardenArranger, Arranging>(GardenArranger.new);

class GardenArranger extends Notifier<Arranging> {
  @override
  Arranging build() {
    // Starting a session closes the arrangement bar. The select stops this
    // firing on every tick.
    ref.listen(
      sessionControllerProvider
          .select((session) => sessionHoldsTheGarden(session.phase)),
      (_, held) {
        if (held) state = const NotArranging();
      },
    );

    return const NotArranging();
  }

  /// Does nothing during a session (the button is disabled then anyway).
  void begin() {
    if (sessionHoldsTheGarden(ref.read(sessionControllerProvider).phase)) {
      return;
    }
    state = const Choosing();
  }

  /// Leaves arranging. Nothing is written or undone; a held item just stays
  /// where it was.
  void end() => state = const NotArranging();

  /// Picks [item] up, so the next plot tapped is where it goes.
  void pickUp(Decor item) => state = HoldingDecor(item);

  /// Picks [plant] up from [plot]. Any planted plant, bonus ones included.
  void pickUpPlant(Plant plant, GardenPlot plot) =>
      state = HoldingPlant(plant, plot);

  /// Puts down whatever is in hand without leaving arranging.
  void putDown() => state = const Choosing();

  /// Stands a new [kind] in [plot]. Stays in [Choosing] so the user can keep
  /// arranging.
  Future<void> place(DecorKind kind, GardenPlot plot) async {
    state = const Choosing();

    await _write('placing a ${kind.name}', () {
      return ref.read(decorRepositoryProvider).save(Decor(
            id: ref.read(idSourceProvider).newId(),
            kind: kind,
            plot: plot,
            placedAt: ref.read(clockProvider).now(),
          ));
    });
  }

  /// Moves what's [held] to [plot], swapping with anything already there
  /// (see [GardenArrangement.exchange]). Ids and dates are kept.
  Future<void> move(Holding held, GardenPlot plot) async {
    state = const Choosing();

    final moved = await _write(
      'moving what was in ${held.plot} to $plot',
      () => ref.read(gardenArrangementProvider).exchange(held.plot, plot),
    );
    if (!moved || !ref.mounted) return;

    _tick();
  }

  /// Moves make no sound, so apart from the garden redrawing this is the
  /// only feedback.
  void _tick() {
    if (ref.read(settingsProvider).hapticsEnabled) {
      unawaited(ref.read(hapticsProvider).arranged());
    }
  }

  /// Moves the plant in hand to the shelf, leaving its soil empty.
  Future<void> shelve(HoldingPlant held) async {
    state = const Choosing();

    final shelved = await _write(
      'shelving plant ${held.plant.id}',
      () => ref.read(gardenArrangementProvider).shelve(held.plant.id),
    );
    if (!shelved || !ref.mounted) return;

    ref
        .read(analyticsProvider)
        .record(PlantShelved(species: held.plant.species));
    _tick();
  }

  /// Stands a shelved [plant] in [plot], chosen in the picker. Stays in
  /// [Choosing] like [place].
  Future<void> replant(Plant plant, GardenPlot plot) async {
    state = const Choosing();

    // The plot may have filled up, or the plant been planted elsewhere,
    // while the picker was open. Then nothing moves.
    var planted = false;
    await _write('replanting ${plant.id} in $plot', () async {
      planted =
          await ref.read(gardenArrangementProvider).replant(plant.id, plot);
    });
    if (!planted || !ref.mounted) return;

    ref.read(analyticsProvider).record(
          PlantReplanted(species: plant.species, pickedPlot: true),
        );
    _tick();
  }

  /// Plants a shelved [plant] in the nearest free plot, for the button on the
  /// shelf. Returns false if every plot has a plant or decor in it: unlike a
  /// new session's plant, one from the shelf never displaces anything.
  ///
  /// Leaves the arranging state alone, since it's called from another tab.
  Future<bool> plantInGarden(Plant plant) async {
    // Also false for the second of two quick taps, so a double tap only
    // ticks and logs once.
    var planted = false;
    await _write('planting ${plant.id} from the shelf', () async {
      final sowing = GardenPlots.sow(
        plants: await ref.read(plantRepositoryProvider).occupiedPlots(),
        decor: await ref.read(decorRepositoryProvider).occupiedPlots(),
      );
      final plot = sowing.plot;
      if (plot == null || sowing.displacing != null) return;

      planted =
          await ref.read(gardenArrangementProvider).replant(plant.id, plot);
    });
    if (!planted || !ref.mounted) return false;

    ref.read(analyticsProvider).record(
          PlantReplanted(species: plant.species, pickedPlot: false),
        );
    _tick();
    return true;
  }

  /// Takes [item] out of the garden.
  Future<void> remove(Decor item) async {
    state = const Choosing();

    await _write(
      'removing a ${item.kind.name}',
      () => ref.read(decorRepositoryProvider).remove(item.id),
    );
  }

  /// Runs a write and refreshes the garden; false if it failed. Reports
  /// failures rather than rethrowing, like `SessionController._write`.
  Future<bool> _write(String what, Future<void> Function() write) async {
    try {
      await write();
      // A swap can touch either table.
      ref.invalidate(plantsProvider);
      ref.invalidate(decorProvider);
      return true;
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription(what),
      ));
      return false;
    }
  }
}
