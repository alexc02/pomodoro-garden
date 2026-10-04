import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../audio/app_audio_session.dart';
import 'ambience.dart';
import 'audio_interruptions.dart';

/// [Ambience] over `just_audio`.
///
/// - Two players, crossfaded, so switching beds mid-session has no gap.
///   (Seamless looping itself comes from the WAV files; see
///   `ambientLoopAsset`.)
/// - Every level change is a fade; an instant stop clicks.
/// - The audio session category is [AppAudioSession]'s job.
/// - [play] calls are queued. Otherwise a fading-out bed can hand the session
///   back to `ambient` after the next bed has already taken `playback`.
final class BundledAmbience implements Ambience {
  BundledAmbience(this._audio, {AudioPlayer? first, AudioPlayer? second})
      : _players = [first ?? AudioPlayer(), second ?? AudioPlayer()];

  /// Well under the chime (mastered at -9 dBFS).
  static const double _bedLevel = 0.55;

  static const double _duckedLevel = 0.15;

  static const Duration _crossfade = Duration(milliseconds: 1200);

  /// Short, so the bed is gone before most of the 3-5 s chime.
  static const Duration _fadeOut = Duration(milliseconds: 800);

  /// For interruptions: fast enough not to talk over a caller, slow enough not
  /// to click.
  static const Duration _outOfTheWay = Duration(milliseconds: 250);

  /// Wait before handing the session back to `ambient`, so a chime still
  /// ringing isn't re-categorised mid-note. Must exceed the longest end sound
  /// (singing bowl, 5 s).
  static const Duration _chimeOutlastsTheBedBy = Duration(seconds: 6);

  /// Steps are inaudible at 40 ms and it keeps platform calls down.
  static const Duration _fadeStep = Duration(milliseconds: 40);

  final AppAudioSession _audio;
  final List<AudioPlayer> _players;
  final AudioInterruptions _interruptions = AudioInterruptions();

  /// Index of the live player in [_players].
  int _live = 0;

  AmbientSound _playing = AmbientSound.silence;

  /// Live player's current volume.
  double _level = 0;

  /// Bumped by every fade so an overtaken fade stops.
  int _fading = 0;

  /// Subscribed on first play only.
  Future<void>? _listening;

  final List<StreamSubscription<void>> _routeEvents =
      <StreamSubscription<void>>[];

  Future<void> _queue = Future<void>.value();

  bool _disposed = false;

  AudioPlayer get _current => _players[_live];
  AudioPlayer get _idle => _players[1 - _live];

  @override
  Future<void> play(AmbientSound sound) => _inTurn(() => _play(sound));

  /// Reports rather than throws; this runs during teardown.
  Future<void> dispose() async {
    _disposed = true;
    // Stops any fade in flight.
    _fading++;

    await _bestEffort('releasing the ambience', () async {
      await Future.wait(_routeEvents.map((events) => events.cancel()));
      await Future.wait(_players.map((player) => player.dispose()));
    });
  }

  Future<void> _play(AmbientSound sound) async {
    final asset = ambientLoopAsset(sound);
    if (asset == null) return _takeTheBedDown();

    // Checking `playing` too lets a bed the platform paused be restarted by
    // asking for the same sound again.
    if (sound == _playing && _current.playing) return;

    await _listenToTheRoute();
    // Before play(): iOS uses whatever category is set when the player starts.
    await _audio.useFor(AudioUse.ambientBed);

    final arriving = _idle;
    await arriving.setAsset(asset);
    await arriving.setLoopMode(LoopMode.one);
    await arriving.setVolume(0);
    unawaited(arriving.play());

    final leaving = _playing == AmbientSound.silence ? null : _current;
    _live = 1 - _live;
    _playing = sound;

    await _crossfadeTo(_bedLevel, over: _crossfade, replacing: leaving);
    // Stop, not pause, to free the decoded file.
    await leaving?.stop();
  }

  Future<void> _takeTheBedDown() async {
    if (_playing == AmbientSound.silence) return;
    _playing = AmbientSound.silence;

    final leaving = _current;
    await _crossfadeTo(0, over: _fadeOut);
    await leaving.stop();
    _interruptions.forget();

    // Let the chime finish first.
    await Future<void>.delayed(_chimeOutlastsTheBedBy);
    await _audio.useFor(AudioUse.chimeOnly);
  }

  /// Queues [work]. Never throws, and a failure doesn't block later work.
  Future<void> _inTurn(Future<void> Function() work) =>
      _queue = _queue.then((_) => _bestEffort('driving the bed', work));

  /// Subscribes once to interruption and route events. [AudioInterruptions]
  /// decides; this just acts on it.
  Future<void> _listenToTheRoute() =>
      _listening ??= AudioSession.instance.then((session) {
        _routeEvents.addAll([
          session.interruptionEventStream
              .listen((event) => _respond(_interruptions.interrupted(event))),
          // Headphones out. audio_session emits this on iOS too.
          session.becomingNoisyEventStream
              .listen((_) => _respond(_interruptions.routeLost())),
          session.devicesChangedEventStream.listen((event) {
            if (event.devicesAdded.isNotEmpty) {
              _respond(_interruptions.routeRegained());
            }
          }),
        ]);
      });

  void _respond(BedResponse? response) {
    if (response == null || _disposed) return;
    if (_playing == AmbientSound.silence) return;

    unawaited(_bestEffort('responding to the route with ${response.name}',
        () async {
      switch (response) {
        case BedResponse.hold:
          await _crossfadeTo(0, over: _outOfTheWay);
          // Pause, not stop, so resuming doesn't reload.
          await _current.pause();
        case BedResponse.resume:
          unawaited(_current.play());
          await _crossfadeTo(_bedLevel, over: _crossfade);
        case BedResponse.duck:
          await _crossfadeTo(_duckedLevel, over: _outOfTheWay);
        case BedResponse.lift:
          await _crossfadeTo(_bedLevel, over: _outOfTheWay);
      }
    }));
  }

  /// Fades the live player to [target] and [replacing] (if any) to zero.
  ///
  /// Equal-power (sin/cos): a linear crossfade of two uncorrelated beds dips
  /// 3 dB in the middle.
  Future<void> _crossfadeTo(
    double target, {
    required Duration over,
    AudioPlayer? replacing,
  }) async {
    final rising = _current;
    final start = replacing == null ? _level : 0.0;
    final leaving = _level;

    final generation = ++_fading;
    final steps = (over.inMicroseconds / _fadeStep.inMicroseconds).ceil();

    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(_fadeStep);
      // Overtaken by a newer fade.
      if (generation != _fading || _disposed) return;

      final turn = math.pi / 2 * step / steps;
      // Update _level every step so an overtaking fade starts from the real
      // volume, not this fade's target (that would jump and click).
      _level = start + (target - start) * math.sin(turn);
      await rising.setVolume(_level);
      await replacing?.setVolume(leaving * math.cos(turn));
    }

    _level = target;
  }

  /// Reports rather than throws. A failed bed never affects the session.
  Future<void> _bestEffort(String what, Future<void> Function() work) async {
    try {
      await work();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription(what),
      ));
    }
  }
}
