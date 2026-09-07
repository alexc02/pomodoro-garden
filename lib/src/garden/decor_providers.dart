import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../data/database_providers.dart';
import '../session/session_providers.dart';
import '../time/clock_provider.dart';
import 'art_providers.dart';
import 'decor_sprite.dart';
import 'placeholder_decor_sprites.dart';

/// Every object in the garden, in the order it was placed.
///
/// Invalidated by [DecorArranger] and by `SessionController` (a completed
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
/// tap on an object picks it up.
final class Choosing extends Arranging {
  const Choosing();
}

/// An object the user has picked up, waiting for somewhere to be put down.
final class Holding extends Arranging {
  const Holding(this.decor);

  final Decor decor;
}

/// Places, moves and removes decor, and tracks what the user is halfway
/// through.
final decorArrangerProvider =
    NotifierProvider<DecorArranger, Arranging>(DecorArranger.new);

class DecorArranger extends Notifier<Arranging> {
  @override
  Arranging build() {
    // Starting a session closes the arrangement bar.
    ref.listen(sessionControllerProvider, (_, session) {
      if (session.phase == SessionPhase.running) state = const NotArranging();
    });

    return const NotArranging();
  }

  void begin() => state = const Choosing();

  /// Leaves arranging. Nothing is written or undone; a held item just stays
  /// where it was.
  void end() => state = const NotArranging();

  /// Picks [item] up, so the next empty plot tapped is where it goes.
  void pickUp(Decor item) => state = Holding(item);

  /// Puts down whatever is in hand without leaving arranging.
  void putDown() => state = const Choosing();

  /// Stands a new [kind] in [plot]. Stays in [Choosing] so the user can keep
  /// arranging.
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

  /// Moves [item] to [plot], keeping its id and placed date (see
  /// [Decor.movedTo]).
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

  /// Runs a write and refreshes the garden. Reports failures rather than
  /// rethrowing, like `SessionController._write`.
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
