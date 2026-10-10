import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../session/session_providers.dart';
import '../settings/settings_providers.dart';
import 'ambience_providers.dart';

/// Keeps what is playing in step with what the timer is doing.
///
/// The fourth of the widgets wrapped around the shell, and it is divided from
/// the other three the same way they are divided from each other — by what it
/// answers to. `SessionLifecycle` is what the app coming and going does to the
/// session; `SessionAnnouncer` is what a session ending *says*;
/// `LiveSurfaceKeeper` is what a session looks like from outside the app; this
/// is what a session in flight *sounds* like.
///
/// Three rules, and each of them is a decision the ticket left open:
///
/// **The bed belongs to a focus session, running or held.** A paused session is
/// a session the user is still in — they have stepped away from the desk, not
/// out of the hour — and a bed that stopped and restarted around a two-minute
/// interruption would put in a gap for exactly the reason the ticket forbids
/// one. Everything else takes the bed down: idle, completed, cancelled.
///
/// **A break has no bed.** It is a rest, and the whole of how this app treats
/// one is by making it plainly not the session — a sky-coloured ring, bare soil,
/// and a screen that says nothing is growing. Rain carrying on through it would
/// say the opposite. The bed comes back when the next session starts.
///
/// **The bed ends by fading, which is also how it gets out of the chime's way.**
/// Asking for `AmbientSound.silence` fades rather than cutting, so the session
/// that ends under a bed is announced by its end sound over a bed that is
/// leaving rather than by two sounds at the same level. That is REQ-031 and
/// REQ-012 settled in one place instead of a duck negotiated between them.
class AmbienceKeeper extends ConsumerStatefulWidget {
  const AmbienceKeeper({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AmbienceKeeper> createState() => _AmbienceKeeperState();
}

class _AmbienceKeeperState extends ConsumerState<AmbienceKeeper> {
  /// What the bed is, as far as this knows. Silence when nothing is playing.
  AmbientSound _playing = AmbientSound.silence;

  AppLifecycleListener? _listener;

  @override
  void initState() {
    super.initState();
    // A force-quit takes the session with it — `SessionLifecycle` voids it —
    // and a bed left playing would be rain for a session that no longer exists.
    // Best-effort like every write during teardown: on both platforms the
    // players die with the process a moment later anyway.
    _listener = AppLifecycleListener(onDetach: () => _sync(stopping: true));

    // Once, before anything has changed. `ref.listen` fires on a change and a
    // launch is not one — so without this, a session restored at launch would
    // wait for its next tick to get its bed back, and a session restored
    // *paused* would wait forever, because a held session's snapshot does not
    // move until the user touches it.
    _sync();
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Both, because either can change what should be playing: the session by
    // starting or ending, the settings by the user picking a different bed
    // from the timer screen. The second is the whole of "changeable
    // mid-session" — a picker that called the player itself would be a second
    // thing driving the bed, and the two would disagree the first time a
    // session ended while the picker was open.
    ref.listen(sessionControllerProvider, (_, _) => _sync());
    ref.listen(settingsProvider, (_, _) => _sync());
    return widget.child;
  }

  /// Puts the bed where the timer and the settings say it should be.
  void _sync({bool stopping = false}) {
    final wanted = stopping
        ? AmbientSound.silence
        : _bedFor(ref.read(sessionControllerProvider).phase);

    if (wanted == _playing) return;
    _playing = wanted;

    unawaited(ref.read(ambienceProvider).play(wanted));
  }

  /// The bed a timer in [phase] should have under it.
  AmbientSound _bedFor(SessionPhase phase) => switch (phase) {
        SessionPhase.running || SessionPhase.paused =>
          ref.read(settingsProvider).ambientSound,
        SessionPhase.idle ||
        SessionPhase.completed ||
        SessionPhase.onBreak ||
        SessionPhase.breakOver =>
          AmbientSound.silence,
      };
}
