import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/app_audio_session.dart';
import 'micro_sounds.dart';

/// [MicroSounds] over `just_audio`, playing the four bundled one-shots.
///
/// **A player per sound, made when that sound is first asked for.** The end
/// sound gets away with one player that swaps its asset because there is only
/// ever one of it in flight; these four are not so tidy — a seed lands 800 ms
/// after the tap that started the session, and a plant can reach a stage while
/// a card is rising. A single player would have one of them cut the other off
/// mid-sound, which is a worse bug than it looks: the sound that gets cut is
/// always the earlier one, so what the user hears is the app interrupting
/// itself. Lazily made, so a run that only ever taps START pays for one.
///
/// **It asks the audio session for nothing.** [AppAudioSession.ensureConfigured]
/// makes sure the session has been set up for *something* without taking it from
/// whatever holds it — so a micro-sound played under a running ambient bed goes
/// out over the bed's `playback` session and never pulls the app back to
/// `ambient` mid-session. That asymmetry is ADR 0009's, and it is why these can
/// be added to four call sites without any of them having to know a bed exists.
///
/// With no bed running the app sits on [AudioUse.chimeOnly] — `ambient` on iOS,
/// the notification usage on Android — which is what makes a silenced phone stay
/// silent through all four. There is no switch of their own; see [MicroSounds].
///
/// **So "a silenced phone stays silent" has one exception, and it is inherited
/// rather than chosen.** A running bed holds the session on `playback`, which
/// ignores the iOS ring switch, and a micro-sound that fired during one would go
/// out over it. The alternative is worse by ADR 0009's own argument: taking the
/// session back to `ambient` for a button tap would silence the rain the user
/// asked for. It is also the end sound's existing behaviour — a user with rain
/// in their ears has asked for audio out loud — so this is the chime's bargain,
/// applied to four quieter sounds, rather than a new one.
final class BundledMicroSounds implements MicroSounds {
  BundledMicroSounds(this._audio);

  final AppAudioSession _audio;

  /// The player for each sound asked for so far, as the *future* of one rather
  /// than the player itself.
  ///
  /// A future is what closes the double-tap race, and the race is real: a decode
  /// takes a moment, and a user can tap PAUSE twice inside one. Keyed on the
  /// player and the two taps would each find nothing in the map, each build a
  /// player, and the second would overwrite the first — leaving a platform
  /// decoder nothing can ever dispose, and one of the two taps inaudible.
  /// Memoising the *load* means the second tap awaits the first one's player and
  /// then seeks it.
  final Map<MicroSound, Future<AudioPlayer>> _players =
      <MicroSound, Future<AudioPlayer>>{};

  /// The one-time audio-session setup, cleared on failure so that one bad
  /// configuration does not silence every sound after it.
  Future<void>? _configured;

  @override
  Future<void> play(MicroSound sound) async {
    try {
      await (_configured ??= _configure());

      final loading = _players[sound];
      final AudioPlayer player;
      if (loading == null) {
        player = await (_players[sound] = _load(sound));
      } else {
        player = await loading;
        // From the top, however far through the last one got. `seek` rather
        // than reloading: the asset is already decoded, and a user tapping
        // PAUSE twice should hear two taps.
        await player.seek(Duration.zero);
      }

      // Not awaited. `play` completes when the sound *finishes*, and every
      // caller here is in the middle of doing something the user is watching.
      unawaited(player.play());
    } catch (error, stack) {
      // A micro-sound that cannot play is a quieter app, not a broken one.
      // Everything these four accompany has already happened by the time this
      // runs — the seed has landed, the session has started, the card is up.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pomodoro_garden',
        context: ErrorDescription('playing the ${sound.stem} micro-sound'),
      ));
    }
  }

  /// A player with [sound] decoded onto it, and nothing left behind if it fails.
  ///
  /// Forgotten from [_players] on failure, so the next attempt tries again
  /// rather than awaiting a future that is only ever going to throw — and the
  /// player is disposed on the way out, because one that never reached the map
  /// is one nothing else can release.
  Future<AudioPlayer> _load(MicroSound sound) async {
    final player = AudioPlayer();
    try {
      await player.setAsset(sound.asset);
      return player;
    } catch (_) {
      // `ignore` rather than awaited: the entry being dropped is this very
      // load, and the caller awaiting it is what handles the failure. Nothing
      // else is listening, and an unlistened failed future is an unhandled
      // async error.
      _players.remove(sound)?.ignore();
      await player.dispose();
      rethrow;
    }
  }

  Future<void> _configure() async {
    try {
      await _audio.ensureConfigured();
    } catch (_) {
      _configured = null;
      rethrow;
    }
  }

  /// Releases every player made. Called when the provider holding this goes.
  ///
  /// Each entry is awaited rather than assumed: a load still in flight has a
  /// decoder to release as much as a finished one does. A load that *failed*
  /// has already disposed its own player and taken itself out of the map, but
  /// it can still be in here if it is mid-throw, so the await is guarded —
  /// disposing must not throw at a provider being torn down.
  Future<void> dispose() async {
    final loading = List.of(_players.values);
    _players.clear();

    for (final player in loading) {
      try {
        await (await player).dispose();
      } catch (_) {
        // Nothing to release, or nothing that can be.
      }
    }
  }
}
