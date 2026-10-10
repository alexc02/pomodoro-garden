import 'package:audio_session/audio_session.dart';

/// What the bed should do about something that happened to the audio route.
enum BedResponse {
  /// Stop, and expect to be started again. The countdown carries on: a phone
  /// call takes the speaker, not the session.
  hold,

  /// Start again, from where it was held.
  resume,

  /// Step back, without stopping — something short is being said over the top.
  duck,

  /// Come back up to the level it was at before the duck.
  lift,
}

/// What a phone call, a navigation prompt or a yanked pair of headphones does
/// to the bed.
///
/// **This exists to be tested.** Two of ticket 10's criteria are about things
/// no widget test can make happen — a call arriving, a Bluetooth speaker
/// walking out of range — and the alternative to pulling the decision out here
/// is a feature whose behaviour is only ever asserted by holding a phone. So
/// the *decisions* live in this class, with no player and no platform in them,
/// and `BundledAmbience` is left with the part that genuinely needs a device.
/// What remains device-only is whether the platform sends the events at all.
///
/// **It is a small state machine rather than a function, because two things can
/// silence the bed at once.** A user on a call who unplugs their headphones
/// mid-call has been interrupted twice; the call ending must not put the rain
/// back through a speaker they just walked away from. So each reason is
/// remembered, and the bed comes back when the last one has gone.
final class AudioInterruptions {
  /// The reasons the bed is currently held. Empty when it is playing.
  final Set<_Silencer> _holding = <_Silencer>{};

  /// Whether the bed is standing back for something rather than stopped for it.
  bool _ducked = false;

  /// What [event] — a phone call, an alarm, a navigation prompt — asks for, or
  /// null if it asks for nothing.
  ///
  /// The three interruption types are three different sentences from the
  /// platform, and they are not interchangeable:
  ///
  /// - **duck** is "carry on, quietly". Android sends it for a transient
  ///   duckable loss when the session is not configured to pause under one,
  ///   which is how `AppAudioSession` configures the bed.
  /// - **pause** is "stop, and you may start again afterwards". Android sends
  ///   it for a transient loss; iOS sends it at the *end* of an interruption
  ///   when the system set `shouldResume`.
  /// - **unknown** is "stop", with no promise. iOS sends it when an
  ///   interruption begins, and at the end of one when `shouldResume` is
  ///   absent — which means something else is playing now.
  ///
  /// **An interruption that ends without `shouldResume` leaves the bed down.**
  /// That is the platform saying another app has the speaker, and rain fading
  /// back in over somebody's podcast would be this app deciding it was more
  /// important than the thing the user just started. The bed stays down for the
  /// rest of that session — picking a *different* one from the timer screen
  /// starts one, and so does the next session.
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

    // The interruption is over either way; whether the bed comes back is what
    // the type decides.
    final released = _release(_Silencer.interruption);
    return event.type == AudioInterruptionType.pause ? released : null;
  }

  /// Headphones pulled out, or a Bluetooth speaker gone.
  ///
  /// Held rather than left playing, which is what every media app on both
  /// platforms does and what the user of a *focus* app wants twice over: the
  /// rain they were listening to privately must not come out of the phone's
  /// speaker into the room they are sitting in.
  BedResponse? routeLost() => _hold(_Silencer.route);

  /// Headphones back in, or the speaker back in range.
  ///
  /// The other half of [routeLost], and the reason this class is worth having:
  /// without it a bed held by a yanked cable stays down for the rest of the
  /// session, which is not a crash and is not orphaned playback but is not
  /// right either.
  BedResponse? routeRegained() => _release(_Silencer.route);

  /// Forgets everything, because there is no bed to hold down any more.
  ///
  /// Called when the bed stops rather than when it is interrupted, and it is
  /// not housekeeping. A session that ends while the headphones are out leaves
  /// [_Silencer.route] held; carried into the next session, the first phone
  /// call would find the bed already "held", do nothing, and leave rain playing
  /// over the caller. What each of these reasons means is *this* bed is down,
  /// and when the bed goes, so do they.
  void forget() {
    _holding.clear();
    _ducked = false;
  }

  BedResponse? _hold(_Silencer reason) {
    // Already down for another reason. Remembered anyway, so that the reason
    // that is fixed first does not bring the bed back over the one that is not.
    final wasPlaying = _holding.isEmpty;
    _holding.add(reason);
    return wasPlaying ? BedResponse.hold : null;
  }

  BedResponse? _release(_Silencer reason) {
    if (!_holding.remove(reason)) return null;
    return _holding.isEmpty ? BedResponse.resume : null;
  }
}

/// Something that has the bed held down.
enum _Silencer { interruption, route }
