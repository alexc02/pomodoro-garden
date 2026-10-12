import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'channel_quiet_mode.dart';
import 'quiet_mode.dart';

/// Puts the phone into Do Not Disturb for a session. Overridden in widget
/// tests (nothing answers the channel there).
final quietModeProvider = Provider<QuietMode>((ref) => ChannelQuietMode());

/// What this phone lets the app do about quiet mode.
///
/// Must be re-checked on every resume: the permission is granted and revoked
/// in system settings, outside the app. `QuietModeKeeper` calls
/// [QuietModeAccessController.refresh] for that.
final quietModeAccessProvider =
    AsyncNotifierProvider<QuietModeAccessController, QuietModeAccess>(
  QuietModeAccessController.new,
);

class QuietModeAccessController extends AsyncNotifier<QuietModeAccess> {
  @override
  Future<QuietModeAccess> build() => ref.watch(quietModeProvider).access();

  /// Keeps the old value while fetching (no loading state) so the switch
  /// doesn't blink on every resume.
  Future<void> refresh() async {
    final access = await ref.read(quietModeProvider).access();
    if (!ref.mounted) return;
    state = AsyncData(access);
  }
}
