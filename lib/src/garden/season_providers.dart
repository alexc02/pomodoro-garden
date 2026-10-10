import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../time/clock_provider.dart';

/// Which half of the world this device is in, read off its time zone.
///
/// A provider rather than a call at the point of use so that a test can put the
/// app in Sydney without moving the machine running it, and so the read happens
/// once instead of per frame. See
/// `docs/adr/0011-the-season-is-derived-from-the-device-date.md` for why a time
/// zone is what gets asked, and what happens in the zones that will not answer.
final hemisphereProvider = Provider<Hemisphere>((ref) {
  // The year the device is in, so a zone that changed its daylight-saving rules
  // is read as it is now rather than as it was in some fixed sample year.
  final year = ref.watch(clockProvider).now().toLocal().year;

  return Hemisphere.fromDaylightSaving(
    january: DateTime(year, 1).timeZoneOffset,
    july: DateTime(year, 7).timeZoneOffset,
  );
});

/// The season a reviewer has pinned the garden to, or null to follow the
/// calendar.
///
/// Not a setting: it is never written to disk, it has no default worth storing,
/// and the only thing that can move it is a control that exists in debug builds
/// alone. A user cannot choose their season — the point of REQ-019 is that
/// nobody had to.
final forcedSeasonProvider =
    NotifierProvider<ForcedSeason, Season?>(ForcedSeason.new);

/// Holds the season the debug affordance has pinned.
class ForcedSeason extends Notifier<Season?> {
  @override
  Season? build() => null;

  /// Pins the garden to [season], or hands it back to the calendar when
  /// [season] is null.
  void force(Season? season) => state = season;
}

/// The season the garden is in.
///
/// Derived from the device's local date and nothing else — no setting, no
/// stored value, no server. The user did nothing to make this happen, which is
/// the whole of what REQ-019 is for.
///
/// It re-reads itself on a timer so that a garden left open across a boundary
/// turns rather than waiting for a relaunch. Whatever this changes to,
/// `SeasonalGarden` crossfades to over three seconds; nothing here knows that.
final seasonProvider =
    NotifierProvider<GardenSeason, Season>(GardenSeason.new);

/// Reads the season off the clock, and looks again when it might have changed.
class GardenSeason extends Notifier<Season> {
  Timer? _nextLook;

  /// The longest this will go without re-reading the clock.
  ///
  /// A season boundary is up to three months away, and a timer set three months
  /// out would miss the two things that can move a boundary underneath it: the
  /// user correcting the device's date, and the device crossing into a time
  /// zone a day away. Looking hourly catches both within the hour, and an hourly
  /// wake in an app that is on screen costs nothing measurable — this is a
  /// foreground timer, disposed with the provider, and REQ-005's promise about
  /// what runs in the background is untouched by it.
  static const Duration longestWait = Duration(hours: 1);

  @override
  Season build() {
    ref.onDispose(_stopLooking);

    final forced = ref.watch(forcedSeasonProvider);
    if (forced != null) {
      // Nothing to wait for: a pinned garden does not turn on its own, and a
      // timer left running behind one would unpin it at the top of the hour.
      _stopLooking();
      return forced;
    }

    // Local, because a season is what is outside the window. The clock is UTC
    // everywhere else in this app for good reasons; this is the presentation
    // edge those reasons point at.
    final now = ref.watch(clockProvider).now().toLocal();
    _lookAgainBefore(Season.boundaryAfter(now).difference(now));

    return Season.on(now, hemisphere: ref.watch(hemisphereProvider));
  }

  /// Re-reads the clock in [untilTheBoundary], or in an hour, whichever is
  /// sooner.
  void _lookAgainBefore(Duration untilTheBoundary) {
    _stopLooking();
    final wait = untilTheBoundary < longestWait ? untilTheBoundary : longestWait;
    // Rebuilding is the whole of the work: [build] re-reads the clock, and
    // Riverpod tells nobody when the season it arrives at is the one already on
    // screen — which is every look but four a year.
    _nextLook = Timer(wait, ref.invalidateSelf);
  }

  void _stopLooking() {
    _nextLook?.cancel();
    _nextLook = null;
  }
}
