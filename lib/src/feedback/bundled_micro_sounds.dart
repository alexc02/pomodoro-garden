import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/app_audio_session.dart';
import 'micro_sounds.dart';

/// [MicroSounds] over `just_audio`.
///
/// One lazily created player per sound, since they can overlap (the seed lands
/// 800 ms after START; a stage can change while a card rises) and one player
/// would cut the earlier sound off.
///
/// Only calls [AppAudioSession.ensureConfigured], so it never steals the
/// session from a playing bed. Side effect: during a bed the session is on
/// `playback`, so a micro-sound ignores the iOS ring switch, same as the end
/// sound.
final class BundledMicroSounds implements MicroSounds {
  BundledMicroSounds(this._audio);

  final AppAudioSession _audio;

  /// Futures, not players, so a double tap during the first decode awaits the
  /// same load instead of creating (and leaking) a second player.
  final Map<MicroSound, Future<AudioPlayer>> _players =
      <MicroSound, Future<AudioPlayer>>{};

  /// Shared one-time setup. Cleared on failure so the next sound retries.
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
        await player.seek(Duration.zero);
      }

      // just_audio's play() completes when the sound finishes.
      unawaited(player.play());
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription('playing the ${sound.stem} micro-sound'),
      ));
    }
  }

  /// On failure, drops the map entry (so the next play retries) and disposes
  /// the player.
  Future<AudioPlayer> _load(MicroSound sound) async {
    final player = AudioPlayer();
    try {
      await player.setAsset(sound.asset);
      return player;
    } catch (_) {
      // The removed entry is this same future; ignore() stops it surfacing as
      // an unhandled async error. The caller still sees the rethrow.
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

  /// Awaits in-flight loads too. Guarded because a load can be mid-failure.
  Future<void> dispose() async {
    final loading = List.of(_players.values);
    _players.clear();

    for (final player in loading) {
      try {
        await (await player).dispose();
      } catch (_) {
      }
    }
  }
}
