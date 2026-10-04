import 'package:audio_session/audio_session.dart';

/// What the bed should do in response to an audio interruption or route
/// change.
enum BedResponse {
  /// Stop for now. The session keeps counting down.
  hold,

  resume,
  duck,

  /// Undo a duck.
  lift,
}

/// Decides what calls, nav prompts and unplugged headphones do to the bed.
/// Pulled out of `BundledAmbience` so it can be unit tested without a device.
///
/// Tracks each reason separately: unplugging during a call, then hanging up,
/// must not resume the bed through the speaker. Resumes only when all reasons
/// are gone.
final class AudioInterruptions {
  final Set<_Silencer> _holding = <_Silencer>{};

  bool _ducked = false;

  /// Response to an interruption, or null for none.
  ///
  /// - duck: Android transient duckable loss (`AppAudioSession` doesn't ask to
  ///   pause for those).
  /// - pause: Android transient loss; iOS end-of-interruption with
  ///   `shouldResume`.
  /// - unknown: iOS interruption start, or end without `shouldResume`.
  ///
  /// Ending without `shouldResume` means another app has the audio, so the bed
  /// stays down until the user picks another sound or starts a new session.
  BedResponse? interrupted(AudioInterruptionEvent event) {
    if (event.begin) {
      if (event.type == AudioInterruptionType.duck) {
        if (_ducked) return null;
        _ducked = true;
        return BedResponse.duck;
      }
      return _hold(_Silencer.interruption);
    }

    if (event.type == AudioInterruptionType.duck) {
      if (!_ducked) return null;
      _ducked = false;
      return BedResponse.lift;
    }

    final released = _release(_Silencer.interruption);
    return event.type == AudioInterruptionType.pause ? released : null;
  }

  /// Headphones unplugged or Bluetooth gone. Hold, so it doesn't start
  /// playing out of the phone speaker.
  BedResponse? routeLost() => _hold(_Silencer.route);

  BedResponse? routeRegained() => _release(_Silencer.route);

  /// Call when the bed stops. Otherwise a reason left over from the last
  /// session (e.g. headphones out) makes the next call think the bed is already
  /// held, and it keeps playing over the call.
  void forget() {
    _holding.clear();
    _ducked = false;
  }

  BedResponse? _hold(_Silencer reason) {
    final wasPlaying = _holding.isEmpty;
    _holding.add(reason);
    return wasPlaying ? BedResponse.hold : null;
  }

  BedResponse? _release(_Silencer reason) {
    if (!_holding.remove(reason)) return null;
    return _holding.isEmpty ? BedResponse.resume : null;
  }
}

enum _Silencer { interruption, route }
