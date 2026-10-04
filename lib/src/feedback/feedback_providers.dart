import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_providers.dart';
import 'bundled_end_sound_player.dart';
import 'bundled_micro_sounds.dart';
import 'end_sound_player.dart';
import 'haptics.dart';
import 'micro_sounds.dart';

/// The end-of-session chime while the app is in front. Also used by the
/// settings picker for previews. Lazy, so no audio session until first use.
final endSoundPlayerProvider = Provider<EndSoundPlayer>((ref) {
  final player = BundledEndSoundPlayer(ref.watch(appAudioSessionProvider));
  ref.onDispose(player.dispose);
  return player;
});

/// The four micro-sounds. Players are created per sound on first use.
final microSoundsProvider = Provider<MicroSounds>((ref) {
  final sounds = BundledMicroSounds(ref.watch(appAudioSessionProvider));
  ref.onDispose(sounds.dispose);
  return sounds;
});

final hapticsProvider = Provider<Haptics>((ref) => const PlatformHaptics());
