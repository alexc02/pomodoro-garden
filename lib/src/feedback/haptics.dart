import 'package:flutter/services.dart';

/// Session-complete and plant-grew haptics. An interface so tests can
/// observe them. Doesn't check the user's setting; `SessionAnnouncer` does.
abstract interface class Haptics {
  Future<void> sessionComplete();

  Future<void> plantGrew();
}

/// Completion is an impact you can feel through a pocket; growth is a
/// selection click, the lightest thing both platforms have.
final class PlatformHaptics implements Haptics {
  const PlatformHaptics();

  @override
  Future<void> sessionComplete() => HapticFeedback.mediumImpact();

  @override
  Future<void> plantGrew() => HapticFeedback.selectionClick();
}
