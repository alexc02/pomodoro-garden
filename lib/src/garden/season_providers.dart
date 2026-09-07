import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../time/clock_provider.dart';

/// Which hemisphere the device is in, inferred from its time zone
/// (when its DST months fall). Zones without DST default to northern.
final hemisphereProvider = Provider<Hemisphere>((ref) {
  // Use the current year so zones that changed their DST rules are read as
  // they are now.
  final year = ref.watch(clockProvider).now().toLocal().year;

  return Hemisphere.fromDaylightSaving(
    january: DateTime(year, 1).timeZoneOffset,
    july: DateTime(year, 7).timeZoneOffset,
  );
});

/// Debug only: pins the garden to a season, or null to follow the calendar.
/// Never stored.
final forcedSeasonProvider =
    NotifierProvider<ForcedSeason, Season?>(ForcedSeason.new);

class ForcedSeason extends Notifier<Season?> {
  @override
  Season? build() => null;

  /// Pins to [season], or back to the calendar when null.
  void force(Season? season) => state = season;
}

/// The season the garden is in, from the device's local date alone.
///
/// Re-checks on a timer so a garden left open across a boundary turns without
/// a relaunch.
final seasonProvider =
    NotifierProvider<GardenSeason, Season>(GardenSeason.new);

class GardenSeason extends Notifier<Season> {
  Timer? _nextLook;

  /// Max time between clock checks. Hourly catches the user changing the date
  /// or crossing time zones, which a timer set months out would miss.
  /// Foreground only; disposed with the provider.
  static const Duration longestWait = Duration(hours: 1);

  @override
  Season build() {
    ref.onDispose(_stopLooking);

    final forced = ref.watch(forcedSeasonProvider);
    if (forced != null) {
      // A leftover timer would unpin it at the top of the hour.
      _stopLooking();
      return forced;
    }

    // Local time on purpose: the rest of the app is UTC, but the season is
    // what's outside the window.
    final now = ref.watch(clockProvider).now().toLocal();
    _lookAgainBefore(Season.boundaryAfter(now).difference(now));

    return Season.on(now, hemisphere: ref.watch(hemisphereProvider));
  }

  /// Re-reads the clock at the boundary or in an hour, whichever is sooner.
  void _lookAgainBefore(Duration untilTheBoundary) {
    _stopLooking();
    final wait = untilTheBoundary < longestWait ? untilTheBoundary : longestWait;
    // Rebuilding re-reads the clock; Riverpod doesn't notify if the season
    // came out the same.
    _nextLook = Timer(wait, ref.invalidateSelf);
  }

  void _stopLooking() {
    _nextLook?.cancel();
    _nextLook = null;
  }
}
