import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../time/clock_provider.dart';
import 'season_providers.dart';

/// Debug only: a fixed time of day for the garden sky. Null follows the clock.
final forcedTimeOfDayProvider =
    NotifierProvider<ForcedTimeOfDay, Duration?>(ForcedTimeOfDay.new);

class ForcedTimeOfDay extends Notifier<Duration?> {
  @override
  Duration? build() => null;

  void force(Duration? sinceMidnight) => state = sinceMidnight;
}

/// Daylight for the garden sky. Updates once a minute.
final daylightProvider =
    NotifierProvider<GardenDaylight, Daylight>(GardenDaylight.new);

class GardenDaylight extends Notifier<Daylight> {
  Timer? _timer;

  @override
  Daylight build() {
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());

    final season = ref.watch(seasonProvider);
    final forced = ref.watch(forcedTimeOfDayProvider);
    if (forced != null) return Daylight.atTimeOfDay(forced, season: season);

    final now = ref.watch(clockProvider).now().toLocal();
    // Wake up on the next minute boundary.
    _timer = Timer(Duration(seconds: 60 - now.second), ref.invalidateSelf);

    return Daylight.at(now, season: season);
  }
}
