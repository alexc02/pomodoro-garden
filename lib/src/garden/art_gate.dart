import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shell/opening_frame.dart';
import 'art_providers.dart';

/// Holds the app back until the art has been decoded.
///
/// Sprites paint synchronously and `GardenAtlas.bake` is synchronous, but PNG
/// decoding isn't, so something has to wait in between. Same shape as
/// `SettingsGate` and `SessionGate`, with the same [OpeningFrame].
///
/// Waits for the load to settle, not for it to succeed: no art or a load error
/// both open on the placeholders. Safe because `ArtBundle.load` never returns a
/// partial set. This is the slowest of the gates.
class ArtGate extends ConsumerWidget {
  const ArtGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final art = ref.watch(artBundleProvider);

    if (art.isLoading) return const OpeningFrame();

    if (art.hasError) {
      // Report, don't throw: missing art shouldn't stop anyone running a
      // session.
      FlutterError.reportError(FlutterErrorDetails(
        exception: art.error!,
        stack: art.stackTrace,
        library: 'pip_garden',
        context: ErrorDescription('loading the art set'),
      ));
    }

    return child;
  }
}
