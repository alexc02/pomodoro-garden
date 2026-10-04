import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_providers.dart';
import 'ambience.dart';
import 'bundled_ambience.dart';

/// What plays under a focus session. Lazy, so a user who never leaves
/// Silence never opens an audio session. Overridden in widget tests.
final ambienceProvider = Provider<Ambience>((ref) {
  final ambience = BundledAmbience(ref.watch(appAudioSessionProvider));
  ref.onDispose(ambience.dispose);
  return ambience;
});
