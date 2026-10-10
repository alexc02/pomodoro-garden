import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shell/opening_frame.dart';
import 'art_providers.dart';

/// Holds the app back until the art has been decoded.
///
/// **The one piece of logic ticket 23 could not avoid**, and the reason its
/// third criterion — *no logic is modified by this ticket* — is not quite
/// achievable. Every sprite paints synchronously and `GardenAtlas.bake` is
/// synchronous, both deliberately: the garden must never have a frame with no
/// texture to draw. Decoding a PNG is asynchronous. Something has to sit between
/// those two facts, and this is it.
///
/// It is the same shape as `SettingsGate` and `SessionGate`, and wears the same
/// [OpeningFrame], so a launch that waits on three things still looks like one
/// wait.
///
/// **It does not gate on success.** A build with no art set runs on ticket 04's
/// placeholder shapes, so what this waits for is the *question being settled* —
/// art or no art — not for art to be there. An error is likewise not a reason to
/// hold the user at a blank screen forever: it is reported, and the app opens on
/// the placeholders. What makes that safe rather than sloppy is that
/// `ArtBundle.load` refuses to return a half-built set, so "fell back" always
/// means "drew circles", never "drew some of the plants".
///
/// PRD §4.4 budgets 1.5s from launch to a visible garden. This is the most
/// expensive of the three gates by a distance — seventy-eight images against
/// two single-row selects — and `docs/performance-record.md` carries what it
/// actually costs.
class ArtGate extends ConsumerWidget {
  const ArtGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final art = ref.watch(artBundleProvider);

    if (art.isLoading) return const OpeningFrame();

    if (art.hasError) {
      // Reported rather than thrown: the art is how the app looks, not how it
      // works, and a user who cannot see their garden's watercolour can still
      // run a session. The same judgement `SettingsGate` makes about a settings
      // read that fails.
      FlutterError.reportError(FlutterErrorDetails(
        exception: art.error!,
        stack: art.stackTrace,
        library: 'pomodoro_garden',
        context: ErrorDescription('loading the art set'),
      ));
    }

    return child;
  }
}
