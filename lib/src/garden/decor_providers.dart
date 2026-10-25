import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../data/database_providers.dart';
import '../session/session_providers.dart';
import '../time/clock_provider.dart';
import 'art_providers.dart';
import 'decor_sprite.dart';
import 'placeholder_decor_sprites.dart';

/// REQ-040's decor: what is standing in the garden, and what the user is in the
/// middle of doing to it.

/// Every object in the garden, in the order it was placed.
///
/// Invalidated by whatever writes to the table, so the garden refreshes on its
/// own: the arranger when the user places, moves or removes something, and
/// `SessionController` on the rare occasion a completed session displaces an
/// item.
final decorProvider = FutureProvider<List<Decor>>(
  (ref) => ref.watch(decorRepositoryProvider).decor(),
);

/// Where every decor object on screen gets its picture.
///
/// A provider rather than a constant for the reason
/// `plantSpriteRegistryProvider` is one: ticket 23 swaps the whole art set by
/// overriding one line, and a test can supply a registry it can assert against.
/// Nothing else in the app is allowed to name a decor image; see
/// `test/garden/sprites_are_the_only_art_test.dart`.
///
/// The same two-way choice `plantSpriteRegistryProvider` makes, for the same
/// reason and off the same bundle: the decoded art if this build ships any,
/// `PlaceholderDecorSpriteRegistry` if it does not.
final decorSpriteRegistryProvider = Provider<DecorSpriteRegistry>(
  (ref) =>
      ref.watch(artBundleProvider).value?.decor ??
      const PlaceholderDecorSpriteRegistry(),
);

/// What the user is in the middle of doing to their arrangement.
///
/// Three states rather than a pair of flags, because they are genuinely three
/// and the screen says something different in each — and because a pair would
/// admit a fourth, *holding a bench while not arranging*, that means nothing.
///
/// There is deliberately no "an object is armed, waiting for a plot" state. The
/// picker opens **for a plot the user has already tapped**, so choosing a
/// lantern is the last step rather than the first: nothing can be armed and
/// forgotten, and a stray tap on the garden cannot leave an object somewhere the
/// user has to go and find.
sealed class Arranging {
  const Arranging();
}

/// The garden is somewhere to look at: taps open plants, and nothing moves.
///
/// Where every launch starts and where the garden spends almost all of its
/// life. Arranging is a mode the user enters deliberately and leaves the same
/// way — REQ-020's card is what a tap is *for*, and a garden where every tap
/// might instead pick up a bench would have made looking at it dangerous.
final class NotArranging extends Arranging {
  const NotArranging();
}

/// Arranging, with nothing in hand: a tap on empty soil opens the picker and a
/// tap on an object picks it up.
final class Choosing extends Arranging {
  const Choosing();
}

/// An object the user has picked up, waiting for somewhere to be put down.
final class Holding extends Arranging {
  const Holding(this.decor);

  final Decor decor;
}

/// Places, moves and removes REQ-040's objects, and remembers what the user is
/// halfway through.
final decorArrangerProvider =
    NotifierProvider<DecorArranger, Arranging>(DecorArranger.new);

class DecorArranger extends Notifier<Arranging> {
  @override
  Arranging build() {
    // A session starting under an open arrangement bar closes it: the garden is
    // not somewhere to be rearranging while a countdown the user started is
    // running behind it.
    ref.listen(sessionControllerProvider, (_, session) {
      if (session.phase == SessionPhase.running) state = const NotArranging();
    });

    return const NotArranging();
  }

  /// Enters arranging.
  void begin() => state = const Choosing();

  /// Leaves arranging, putting down whatever was in hand.
  ///
  /// Nothing is written and nothing is undone: an object that was moved was
  /// moved, and one that was picked up and not put anywhere is still standing
  /// where it was. Holding an item is a thing the *screen* is doing, not a
  /// thing the garden is.
  void end() => state = const NotArranging();

  /// Picks [item] up, so the next empty plot tapped is where it goes.
  void pickUp(Decor item) => state = Holding(item);

  /// Puts down whatever is in hand without leaving arranging.
  void putDown() => state = const Choosing();

  /// Stands a new [kind] in [plot].
  ///
  /// Left in [Choosing] afterwards, so that the user can go on arranging
  /// without re-entering the mode, and so that placing three lanterns is three
  /// deliberate choices rather than one armed picker and three taps.
  Future<void> place(DecorKind kind, GardenPlot plot) async {
    state = const Choosing();

    await _write('placing a ${kind.name}', (decor) async {
      await decor.save(Decor(
        id: ref.read(idSourceProvider).newId(),
        kind: kind,
        plot: plot,
        placedAt: ref.read(clockProvider).now(),
      ));
    });
  }

  /// Moves [item] to [plot].
  ///
  /// The same object with a different plot — see [Decor.movedTo] — so the id
  /// and the day it was placed survive, and the arrangement's order does not
  /// reshuffle because something was nudged one plot along.
  Future<void> move(Decor item, GardenPlot plot) async {
    state = const Choosing();

    await _write(
      'moving a ${item.kind.name}',
      (decor) => decor.save(item.movedTo(plot)),
    );
  }

  /// Takes [item] out of the garden.
  Future<void> remove(Decor item) async {
    state = const Choosing();

    await _write(
      'removing a ${item.kind.name}',
      (decor) => decor.remove(item.id),
    );
  }

  /// Runs a write against the arrangement and refreshes the garden.
  ///
  /// Reports rather than rethrows, the same judgement `SessionController._write`
  /// makes: a failed write is worth knowing about loudly and is not worth taking
  /// the screen down for. What is lost is one object; what a rethrow would cost
  /// is the garden.
  Future<void> _write(
    String what,
    Future<void> Function(DecorRepository decor) write,
  ) async {
    try {
      await write(ref.read(decorRepositoryProvider));
      ref.invalidate(decorProvider);
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription(what),
      ));
    }
  }
}
