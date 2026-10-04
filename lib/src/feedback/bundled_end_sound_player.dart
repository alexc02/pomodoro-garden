import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../audio/app_audio_session.dart';
import 'end_sound_player.dart';

/// [EndSoundPlayer] over `just_audio`. Foreground only; in the background the
/// notification plays the same file.
///
/// Uses [AudioUse.chimeOnly] (iOS `ambient`, Android notification usage) so
/// the silent switch mutes it, unless an ambient bed already has the session
/// on `playback`; see [AppAudioSession]. Mixes with other audio rather than
/// interrupting it.
final class BundledEndSoundPlayer implements EndSoundPlayer {
  BundledEndSoundPlayer(this._audio, {AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AppAudioSession _audio;
  final AudioPlayer _player;

  /// Shared one-time setup. Cleared on failure so the next sound retries.
  Future<void>? _configured;

  /// Which sound is loaded, so a repeat can seek instead of reloading.
  EndSound? _loaded;

  @override
  Future<void> play(EndSound sound) async {
    final asset = endSoundAsset(sound);
    if (asset == null) return;

    try {
      await (_configured ??= _configure());

      if (_loaded == sound) {
        await _player.seek(Duration.zero);
      } else {
        // Clear first: if setAsset throws the player is empty, and a stale
        // _loaded would make every later play seek on nothing.
        _loaded = null;
        await _player.setAsset(asset);
        _loaded = sound;
      }

      // just_audio's play() completes when the sound finishes.
      unawaited(_player.play());
    } catch (error, stack) {
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

  Future<void> dispose() => _player.dispose();
}
