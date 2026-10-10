import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'channel_quiet_mode.dart';
import 'quiet_mode.dart';

/// How the phone is asked to go quiet for a session. REQ-014.
///
/// Read by `QuietModeKeeper`, by the settings screen's one control, and by
/// nothing else. Overridden in every widget test — the real one would call
/// across a channel nothing answers on the machine running the suite — and the
/// fake is what makes "was the phone silenced for that session" a question a
/// test can ask.
final quietModeProvider = Provider<QuietMode>((ref) => ChannelQuietMode());

/// What this phone will let the app do about quiet mode, as of the last time
/// anyone looked.
///
/// **Asked again on every resume, and that is a requirement rather than
/// housekeeping.** Notification policy access is granted and revoked from
/// system settings — somewhere the user can only get to by leaving this app —
/// so a cached answer is exactly how a revoked permission turns into a switch
/// that is on and quietly does nothing. `QuietModeKeeper` is what calls
/// [QuietModeAccessController.refresh] when the app comes back.
///
/// Async because the answer crosses a channel. Nothing waits for it: the
/// settings screen shows its quiet-mode section once the answer is in, which is
/// the first frame in every ordinary case, and the keeper reads it as it goes.
final quietModeAccessProvider =
    AsyncNotifierProvider<QuietModeAccessController, QuietModeAccess>(
  QuietModeAccessController.new,
);

/// Reads [QuietMode.access] at launch, and again whenever the app is asked to
/// look.
class QuietModeAccessController extends AsyncNotifier<QuietModeAccess> {
  @override
  Future<QuietModeAccess> build() => ref.watch(quietModeProvider).access();

  /// Asks the platform again.
  ///
  /// The old answer stays on screen while the new one is fetched — this is a
  /// question that is nearly always answered the same way, and a control that
  /// blinked out and back on every return to the app would be worse than one
  /// that is a frame stale.
  Future<void> refresh() async {
    final access = await ref.read(quietModeProvider).access();
    // A refresh that outlived the scope it belongs to — the app is being torn
    // down, and there is nothing left to tell.
    if (!ref.mounted) return;
    state = AsyncData(access);
  }
}
