import 'dart:math' as math;

import 'season.dart';

/// Light level and sun/moon position for a local time of day.
///
/// Sunrise and sunset are fixed per season, so no location is needed.
final class Daylight {
  const Daylight({
    required this.light,
    required this.warmth,
    required this.sunUp,
    required this.arc,
  });

  /// [local] must be local time. Seconds are ignored.
  factory Daylight.at(DateTime local, {required Season season}) =>
      Daylight.atTimeOfDay(
        Duration(hours: local.hour, minutes: local.minute),
        season: season,
      );

  factory Daylight.atTimeOfDay(
    Duration sinceMidnight, {
    required Season season,
  }) {
    const day = 24 * 60;
    final minute = sinceMidnight.inMinutes % day;
    final rise = sunriseIn(season).inMinutes;
    final set = sunsetIn(season).inMinutes;

    // Twilight is centred on sunrise/sunset.
    final ramp = twilight.inMinutes;
    final rising = ((minute - rise) / ramp + 0.5).clamp(0.0, 1.0);
    final setting = (0.5 - (minute - set) / ramp).clamp(0.0, 1.0);

    final fromEdge = math.min((minute - rise).abs(), (minute - set).abs());
    final sunUp = minute >= rise && minute < set;

    return Daylight(
      light: math.min(rising, setting),
      warmth: math.max(0, 1 - fromEdge / goldenHour.inMinutes),
      sunUp: sunUp,
      arc: sunUp
          ? (minute - rise) / (set - rise)
          : ((minute - set) % day) / (day - set + rise),
    );
  }

  static const Duration twilight = Duration(minutes: 90);
  static const Duration goldenHour = Duration(minutes: 75);

  static Duration sunriseIn(Season season) => switch (season) {
        Season.spring => const Duration(hours: 6, minutes: 30),
        Season.summer => const Duration(hours: 5, minutes: 30),
        Season.autumn => const Duration(hours: 7),
        Season.winter => const Duration(hours: 8),
      };

  static Duration sunsetIn(Season season) => switch (season) {
        Season.spring => const Duration(hours: 19),
        Season.summer => const Duration(hours: 21),
        Season.autumn => const Duration(hours: 18, minutes: 30),
        Season.winter => const Duration(hours: 16, minutes: 30),
      };

  /// 0 at night, 1 in full daylight.
  final double light;

  /// 1 at sunrise and sunset, 0 once [goldenHour] has passed.
  final double warmth;

  final bool sunUp;

  /// Progress of the sun (or the moon, at night) across the sky, 0 to 1.
  final double arc;

  @override
  bool operator ==(Object other) =>
      other is Daylight &&
      other.light == light &&
      other.warmth == warmth &&
      other.sunUp == sunUp &&
      other.arc == arc;

  @override
  int get hashCode => Object.hash(light, warmth, sunUp, arc);
}
