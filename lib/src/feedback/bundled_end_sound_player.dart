import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../audio/app_audio_session.dart';
import 'end_sound_player.dart';

/// [EndSoundPlayer] over `just_audio`, playing whichever of REQ-031's bundled
/// sounds the user chose.
///
/// Three things about it are decisions rather than plumbing.
///
/// **The silent switch wins — unless the user asked for a bed.** This asks
/// [AppAudioSession] for [AudioUse.chimeOnly], which is `ambient` on iOS: the
/// category the ring switch mutes. `playback` — the obvious choice for an app
/// that means to be heard — deliberately ignores it, and a focus app that
/// chimed in a meeting because the user had silenced their phone would have
/// earned every word of the review. Android's counterpart is asking for the
/// notification usage, which the ringer mode governs the same way.
///
/// A running ambient bed puts the session on `playback` for as long as it
/// plays, and this does *not* take it back mid-session: a user with rain in
/// their ears has asked for audio out loud, and the sound that ends the session
/// belongs with it. Ticket 10's `AmbienceKeeper` hands the session back when the
/// bed goes. [AppAudioSession] is where that argument is written down.
///
/// **It mixes rather than interrupts.** A user who focuses to music should
/// still have music afterwards, so it ducks nothing and stops nothing.
///
/// **[EndSound.none] costs nothing.** It returns before touching the audio
/// session, so a user who has chosen no sound never has this app take audio
/// focus, open an iOS category or spin up a decoder. Silence here is the
/// absence of the machinery, not the machinery playing an empty file.
///
/// This plays only while the app is in front. A session that ends in the user's
/// pocket is announced by the notification, which carries the same file — see
/// `lib/src/notifications/`.
final class BundledEndSoundPlayer implements EndSoundPlayer {
  BundledEndSoundPlayer(this._audio, {AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AppAudioSession _audio;
  final AudioPlayer _player;

  /// The one-time audio-session setup, kept so that the second sound of the day
  /// does not pay for it again — and so two sounds close together cannot run it
  /// twice. Cleared on failure, so a session that could not be configured once
  /// does not condemn every sound after it to silence.
  Future<void>? _configured;

  /// Which sound the player currently holds decoded, if any.
  ///
  /// The reason this class is not stateless: a user who changes their mind in
  /// settings makes the *next* sound a different file, and reloading one that
  /// is already loaded would throw away a decode for nothing.
  EndSound? _loaded;

  @override
  Future<void> play(EndSound sound) async {
    final asset = endSoundAsset(sound);
    // Nothing to play, and nothing opened in order to play it.
    if (asset == null) return;

    try {
      await (_configured ??= _configure());

      if (_loaded == sound) {
        // From the top, however far through the last one got. `seek` rather
        // than reloading: the asset is already decoded.
        await _player.seek(Duration.zero);
      } else {
        // Forgotten *before* the load rather than remembered after it. A
        // `setAsset` that throws leaves the player holding nothing, and a
        // `_loaded` still naming this sound would send the next attempt down
        // the `seek` branch of a player with no source — silence for the rest
        // of the run, from one bad decode.
        _loaded = null;
        await _player.setAsset(asset);
        _loaded = sound;
      }

      // Not awaited. `play` completes when the sound *finishes*, and the caller
      // is a session that has just ended — it has a screen to put a plant on.
      unawaited(_player.play());
    } catch (error, stack) {
      // A sound that cannot play is a quiet completion, not a failed one. The
      // session is already recorded by the time this runs.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription('playing the end-of-session sound'),
      ));
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

  /// Releases the player. Called when the provider holding it goes.
  Future<void> dispose() => _player.dispose();
}
