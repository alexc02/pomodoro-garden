import 'package:flutter/services.dart';

/// REQ-037's two taps: one for a session that finished, a lighter one for a
/// plant that grew.
///
/// A port so a widget test can watch for them — a haptic leaves no trace on
/// screen, so the alternative is a feature nothing can assert about.
///
/// Neither method consults the user's setting. Whether the phone is allowed to
/// buzz is a question about the app, not about the vibrator, and it is answered
/// once in `SessionAnnouncer` where the reason for the buzz is known.
abstract interface class Haptics {
  /// The gentle success tap of a completed session.
  Future<void> sessionComplete();

  /// The subtler one for a plant reaching its next growth stage.
  Future<void> plantGrew();
}

/// [Haptics] through Flutter's own haptic feedback.
///
/// The two are deliberately different weights. A completion is a small event
/// worth feeling through a pocket, so it is an impact; a growth stage is
/// something the user is invited to notice rather than told about, so it is a
/// selection click — the lightest thing both platforms have.
final class PlatformHaptics implements Haptics {
  const PlatformHaptics();

  @override
  Future<void> sessionComplete() => HapticFeedback.mediumImpact();

  @override
  Future<void> plantGrew() => HapticFeedback.selectionClick();
}
