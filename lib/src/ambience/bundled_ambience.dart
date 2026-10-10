import 'dart:async';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../audio/app_audio_session.dart';
import 'ambience.dart';
import 'audio_interruptions.dart';

/// [Ambience] over `just_audio`, playing the bundled loops.
///
/// Four decisions are worth reading before changing anything here.
///
/// **Two players, so that changing bed mid-session has no gap.** One player
/// cannot swap its source without a silence while the new one loads, and
/// REQ-012's whole point is a bed with no holes in it. So the idle player is
/// loaded and started at zero, the two are crossfaded past each other, and the
/// one that was playing is released. Which of the two is live is the only state
/// this class keeps about what is playing.
///
/// **The loop itself is seamless because of the file, not because of this.**
/// `LoopMode.one` over uncompressed PCM restarts sample-accurately; the same
/// call over AAC splices in the codec's encoder delay. See `ambientLoopAsset`.
///
/// **Nothing here cuts.** Every level change is a fade — starting, stopping,
/// ducking, swapping — because a bed at level that stops instantly is a click,
/// and a click is the seam the ticket forbids arriving by another route.
/// Session end fades rather than stops for a second reason: it is what keeps
/// the end sound audible over the bed instead of the two fighting.
///
/// **The audio session belongs to [AppAudioSession], not to this.** A bed
/// playing means the whole app is on the `playback` category; a bed stopping
/// hands it back. See that class for why there can only be one owner.
///
/// **Calls are queued, not concurrent.** Each one is a second or more of fading
/// with several awaits in it, and two arrive back to back in the ordinary case —
/// a session completes, and the user taps START before the bed has finished
/// leaving. Interleaved, the ending bed's last act is handing the audio session
/// back to the chime, *after* the new bed took it: rain on the `ambient`
/// category, silenced by a ring switch and stopped by a lock screen, on a
/// device, with nothing in the code to point at. Queued, each finishes what it
/// started before the next one begins.
final class BundledAmbience implements Ambience {
  BundledAmbience(this._audio, {AudioPlayer? first, AudioPlayer? second})
      : _players = [first ?? AudioPlayer(), second ?? AudioPlayer()];

  /// Where a bed sits: under everything, and well under the chime.
  ///
  /// Not 1.0, and the number is a decision rather than a taste. A focus bed is
  /// something the user stops noticing, and one at full scale is something they
  /// turn off — while REQ-008's chime, which has to be heard over it, is
  /// mastered at -9 dBFS with headroom of its own.
  static const double _bedLevel = 0.55;

  /// Where a bed stands back to while something short is said over it.
  static const double _duckedLevel = 0.15;

  /// How long a bed takes to arrive, and how long the one it replaces takes to
  /// leave. Long enough not to be a switch, short enough that a user tapping
  /// Rain hears rain rather than wondering whether the tap landed.
  static const Duration _crossfade = Duration(milliseconds: 1200);

  /// How long the bed takes to go when the session it belonged to ends.
  ///
  /// A fifth of the shortest chime it is going under. REQ-031's sounds ring for
  /// three to five seconds and have to be heard over the bed, so the bed's whole
  /// job at this moment is to get out of the way — and it still fades rather
  /// than cutting, because a bed at level that stops instantly is a click.
  static const Duration _fadeOut = Duration(milliseconds: 800);

  /// How long the bed takes to get out of the way of an interruption.
  ///
  /// Much shorter than either of the others, and it has to be: a phone call
  /// starts talking immediately, and a bed that took a second and a half to
  /// leave would be a second and a half of rain over the first thing the caller
  /// said. Short enough to be prompt, long enough not to be a click.
  static const Duration _outOfTheWay = Duration(milliseconds: 250);

  /// How much longer than the bed's fade the chime over it goes on ringing.
  ///
  /// A number about the *chime* kept here, which is a coupling worth naming
  /// rather than hiding: the audio session is shared, and handing it back while
  /// something is still playing on it re-categorises that something mid-note.
  /// Generous — six seconds against the longest of REQ-031's end sounds, the
  /// singing bowl's five — because being early is a truncated chime and being
  /// late is a category held for a moment longer by an app that has already
  /// stopped making noise.
  ///
  /// It was five while ticket 06's four-second wind chime was the only sound
  /// there was. REQ-031 brought a longer one, and a margin exactly equal to the
  /// longest sound is not a margin.
  static const Duration _chimeOutlastsTheBedBy = Duration(seconds: 6);

  /// How often a fade moves. Every 40 ms is inaudible as steps and is thirty
  /// platform calls for a crossfade rather than a hundred.
  static const Duration _fadeStep = Duration(milliseconds: 40);

  final AppAudioSession _audio;
  final List<AudioPlayer> _players;
  final AudioInterruptions _interruptions = AudioInterruptions();

  /// Which of [_players] holds the bed that is playing. The other is idle.
  int _live = 0;

  /// What the live player is playing, or [AmbientSound.silence] when nothing
  /// is.
  AmbientSound _playing = AmbientSound.silence;

  /// Where the live player's fader is, so a duck can come back to it.
  double _level = 0;

  /// Bumped by every fade, so a fade that has been overtaken stops rather than
  /// carrying on writing volumes underneath the one that replaced it.
  int _fading = 0;

  /// Set once, the first time a bed plays. Nothing subscribes on a launch that
  /// never plays one.
  Future<void>? _listening;

  /// What [_listening] opened, so that disposing closes it.
  final List<StreamSubscription<void>> _routeEvents =
      <StreamSubscription<void>>[];

  /// The tail of the [play] / [stop] queue. See the class comment.
  Future<void> _queue = Future<void>.value();

  bool _disposed = false;

  AudioPlayer get _current => _players[_live];
  AudioPlayer get _idle => _players[1 - _live];

  @override
  Future<void> play(AmbientSound sound) => _inTurn(() => _play(sound));

  /// Releases both players and everything listening to the route.
  ///
  /// Called when the provider holding this goes, which on a phone means the app
  /// is being torn down — so it reports rather than throws, like every other
  /// write during teardown in this app.
  Future<void> dispose() async {
    _disposed = true;
    // Any fade in flight sees a generation it does not own and walks away,
    // rather than setting a volume on a player that is being released.
    _fading++;

    await _bestEffort('releasing the ambience', () async {
      await Future.wait(_routeEvents.map((events) => events.cancel()));
      await Future.wait(_players.map((player) => player.dispose()));
    });
  }

  Future<void> _play(AmbientSound sound) async {
    final asset = ambientLoopAsset(sound);
    // Silence, or a bed this build has no file for. Either way there is nothing
    // to play, and taking the bed down is the honest answer to both.
    if (asset == null) return _takeTheBedDown();

    // Already what was asked for, and playing. Reloading it would put a hole
    // in the one thing this class exists to keep whole. The `playing` half is
    // what lets a bed the platform held — headphones out, then back — be
    // started again by asking for it, rather than only by asking for a
    // different one.
    if (sound == _playing && _current.playing) return;

    await _listenToTheRoute();
    // Before the player starts, not after: on iOS the category in force when
    // a player begins is the one it plays under, so configuring afterwards
    // would leave the first bed of the session muted by the ring switch.
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
    // Released rather than paused: the bed that left is not coming back, and
    // a player holding a decoded file it will never play again is 1.3 MB of
    // a phone's memory for nothing.
    await leaving?.stop();
  }

  Future<void> _takeTheBedDown() async {
    if (_playing == AmbientSound.silence) return;
    _playing = AmbientSound.silence;

    final leaving = _current;
    await _crossfadeTo(0, over: _fadeOut);
    await leaving.stop();
    // Nothing is holding the bed down any more, because there is no bed. Left
    // as it was, a session that ended while the headphones were out would hand
    // the *next* session an interruption tracker that thinks the bed is already
    // held — and a phone call during that session would do nothing at all.
    _interruptions.forget();

    // Held for a moment before handing the session back. REQ-008's chime is
    // playing on this session right now, and it outlasts the bed by seconds:
    // released immediately, the last three seconds of it would be re-categorised
    // to `ambient` mid-ring and muted on a silenced phone — half a chime, which
    // is worse than either whole answer. See ADR 0009.
    await Future<void>.delayed(_chimeOutlastsTheBedBy);
    // Now the session goes back to ticket 06's shape, and the ring switch wins
    // again for a user who has asked for quiet.
    await _audio.useFor(AudioUse.chimeOnly);
  }

  /// Runs [work] after everything already asked for, and never throws.
  ///
  /// The queue carries no failure forward: a bed that would not load must not
  /// stop the next one from being tried, and the caller is a keeper reacting to
  /// a session that has already been recorded either way.
  Future<void> _inTurn(Future<void> Function() work) =>
      _queue = _queue.then((_) => _bestEffort('driving the bed', work));

  /// Subscribes to everything the platform has to say about the route, once.
  ///
  /// The decisions are all [AudioInterruptions]'s; what is left here is doing
  /// what it says, which is the part that needs a player.
  Future<void> _listenToTheRoute() =>
      _listening ??= AudioSession.instance.then((session) {
        _routeEvents.addAll([
          session.interruptionEventStream
              .listen((event) => _respond(_interruptions.interrupted(event))),
          // Headphones out, on both platforms: Android raises it directly, and
          // audio_session raises it on iOS for a route change that removed the
          // device that was playing.
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
          // Held, not stopped: the asset stays decoded, so coming back from a
          // two-minute call is a `play` rather than a reload.
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

  /// Walks the live player's volume to [target], while [replacing] — the bed it
  /// is taking over from, if there is one — goes the other way to zero.
  ///
  /// Equal power rather than equal amplitude, for the reason the loops
  /// themselves are crossfaded that way: two uncorrelated beds faded past each
  /// other linearly dip by 3 dB in the middle, which is a hole in the bed even
  /// though no player ever stopped. `sin² + cos² = 1` is what makes the pair
  /// add up to the level they started at, all the way across.
  Future<void> _crossfadeTo(
    double target, {
    required Duration over,
    AudioPlayer? replacing,
  }) async {
    final rising = _current;
    // A bed arriving over another one starts at nothing; a bed already playing
    // that is only changing level starts where it is.
    final start = replacing == null ? _level : 0.0;
    final leaving = _level;

    final generation = ++_fading;
    final steps = (over.inMicroseconds / _fadeStep.inMicroseconds).ceil();

    for (var step = 1; step <= steps; step++) {
      await Future<void>.delayed(_fadeStep);
      // A newer fade — a bed over a bed, a lift over a duck — has taken the
      // faders. Walking away is what makes the last one asked for the one that
      // lands.
      if (generation != _fading || _disposed) return;

      final turn = math.pi / 2 * step / steps;
      // Written down every step, not only at the end. A fade that is overtaken
      // never reaches its target, and a `_level` left at the target it did not
      // reach is what the fade *replacing* it would start from — computing a
      // ramp from 0.55 while the player sits at 0.30, and jumping the last
      // quarter in a single step. That is the click this class is written to
      // avoid, arriving through the only door left open.
      _level = start + (target - start) * math.sin(turn);
      await rising.setVolume(_level);
      await replacing?.setVolume(leaving * math.cos(turn));
    }

    _level = target;
  }

  /// Runs [work], and reports rather than throws if it fails.
  ///
  /// A bed that will not play is a quiet session, not a broken one — the
  /// countdown, the plant and the record of the session are untouched by every
  /// failure this class can have.
  Future<void> _bestEffort(String what, Future<void> Function() work) async {
    try {
      await work();
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pomodoro_garden',
        context: ErrorDescription(what),
      ));
    }
  }
}
