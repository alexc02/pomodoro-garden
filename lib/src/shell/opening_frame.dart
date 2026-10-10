import 'package:flutter/material.dart';

import '../design/spacing.dart';

/// The frame between launch and the shell: the app's own background, and the
/// seedling, held still.
///
/// Shown by every gate that holds the app back at launch, so that a launch
/// which waits on two reads looks like one wait rather than two — the same
/// widget stays on screen across both, and nothing flickers between them.
///
/// No spinner: the reads behind it are single-row selects on an already-open
/// connection, and at that length a spinner would only flash.
class OpeningFrame extends StatelessWidget {
  const OpeningFrame({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Icon(
          Icons.local_florist_outlined,
          size: IconSizes.hero,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
