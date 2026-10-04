import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_audio_session.dart';

/// The app's one audio session, shared by the chime and the ambient bed.
/// See [AppAudioSession] for why they can't each configure their own.
final appAudioSessionProvider = Provider<AppAudioSession>(
  (ref) => AppAudioSession(),
);
