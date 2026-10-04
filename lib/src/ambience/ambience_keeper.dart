import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../session/session_providers.dart';
import '../settings/settings_providers.dart';
import 'ambience_providers.dart';

/// Keeps the ambient bed in step with the timer.
///
/// The bed plays while a focus session is running or paused (pausing
/// shouldn't put a gap in it). Breaks, idle and completed are silent. Stopping
/// fades out, which also keeps it from clashing with the end chime.
class AmbienceKeeper extends ConsumerStatefulWidget {
  const AmbienceKeeper({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AmbienceKeeper> createState() => _AmbienceKeeperState();
}

class _AmbienceKeeperState extends ConsumerState<AmbienceKeeper> {
  AmbientSound _playing = AmbientSound.silence;

  AppLifecycleListener? _listener;

  @override
  void initState() {
    super.initState();
    // Force-quit voids the session, so stop the bed too. Best-effort.
    _listener = AppLifecycleListener(onDetach: () => _sync(stopping: true));

    // ref.listen won't fire for a session restored at launch (and a paused
    // one never ticks), so sync once now.
    _sync();
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Settings too, so changing the bed mid-session goes through here rather
    // than the picker driving the player directly.
    ref.listen(sessionControllerProvider, (_, _) => _sync());
    ref.listen(settingsProvider, (_, _) => _sync());
    return widget.child;
  }

  void _sync({bool stopping = false}) {
    final wanted = stopping
        ? AmbientSound.silence
        : _bedFor(ref.read(sessionControllerProvider).phase);

    if (wanted == _playing) return;
    _playing = wanted;

    unawaited(ref.read(ambienceProvider).play(wanted));
  }

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
