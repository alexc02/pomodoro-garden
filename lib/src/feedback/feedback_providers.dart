import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_providers.dart';
import 'bundled_end_sound_player.dart';
import 'bundled_micro_sounds.dart';
import 'end_sound_player.dart';
import 'haptics.dart';
import 'micro_sounds.dart';

/// What a finished session sounds like while the app is in front. REQ-008,
/// REQ-031.
///
/// Built lazily, and read by `SessionAnnouncer` and by the settings picker that
/// previews a choice: the player is not created until the first sound of the
/// app's life is asked for, so a launch that never runs a session and never
/// opens settings never opens an audio session at all.
final endSoundPlayerProvider = Provider<EndSoundPlayer>((ref) {
  final player = BundledEndSoundPlayer(ref.watch(appAudioSessionProvider));
  ref.onDispose(player.dispose);
  return player;
});

/// PRD §5.4's four micro-sounds. Ticket 26.
///
/// Lazy in two layers: this builds nothing until a call site asks for a sound,
/// and `BundledMicroSounds` makes no player until a *particular* sound is asked
/// for. A launch that starts no session and grows nothing opens no audio session
/// and holds no player.
final microSoundsProvider = Provider<MicroSounds>((ref) {
  final sounds = BundledMicroSounds(ref.watch(appAudioSessionProvider));
  ref.onDispose(sounds.dispose);
  return sounds;
});

/// The phone's answer in the hand. REQ-037.
final hapticsProvider = Provider<Haptics>((ref) => const PlatformHaptics());
