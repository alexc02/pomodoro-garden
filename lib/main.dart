import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';

void main() {
  runApp(
    // The one ProviderScope for the running app. Tests build their own, with
    // overrides in place of the production dependencies.
    const ProviderScope(child: PipGardenApp()),
  );
}
