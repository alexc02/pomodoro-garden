import 'package:flutter/material.dart';

import '../design/spacing.dart';

/// What the launch gates show while they wait. Shared so two gates in a row
/// look like one wait. No spinner: the reads are quick enough that it would
/// only flash.
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
