import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_audio_session.dart';

/// The app's one audio session, shared by the chime and the ambient bed.
///
/// A provider rather than a singleton so that the sharing is visible: there is
/// one of these because the platform has one, and two features reading the same
/// provider is what says so in code. See [AppAudioSession] for what goes wrong
/// when each of them configures its own.
///
/// Never overridden in tests, and never read in one either: both of the things
/// that reach it are ports, and the harness replaces those.
final appAudioSessionProvider = Provider<AppAudioSession>(
  (ref) => AppAudioSession(),
);
