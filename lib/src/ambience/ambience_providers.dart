import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_providers.dart';
import 'ambience.dart';
import 'bundled_ambience.dart';

/// What plays under a focus session. REQ-012.
///
/// Built lazily, and read only by `AmbienceKeeper`: the two players are not
/// created until the first session with a bed under it, so a launch by a user
/// who has never left Silence opens no audio session at all.
///
/// Overridden in every widget test — the real one would decode 1.3 MB of PCM on
/// a machine with no audio device — and the fake is what makes "was there rain
/// under that session" a question a test can ask.
final ambienceProvider = Provider<Ambience>((ref) {
  final ambience = BundledAmbience(ref.watch(appAudioSessionProvider));
  ref.onDispose(ambience.dispose);
  return ambience;
});
