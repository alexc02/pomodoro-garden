import 'dart:math' as math;

import 'package:pomodoro_domain/pomodoro_domain.dart';

/// REQ-023's ambient sway, as arithmetic rather than as a widget.
///
/// §5.3 asks for one motion — *a mature plant leans two degrees on a four-second
/// loop, offset per plant* — and it is drawn in two completely different ways.
/// On the timer screen [GrowingPlant] leans one plant through a `CustomPaint` of
/// its own; in the garden the same lean is the rotation field of one quad in
/// [GardenPainter]'s `drawAtlas` batch, two hundred at a time. The two share
/// nothing structurally and must agree exactly, because the plant a user watched
/// grow on the timer is the plant they then find in the garden: a different
/// period, a different amplitude or a different phase would make it visibly a
/// different plant.
///
/// So the motion lives here and the two renderers ask it. What each of them owns
/// is when to run it and how to apply the answer.
///
/// **The phase is the plant's, not the clock's.** Every plant in the garden is
/// swaying off one controller — there is no per-plant ticker, and two hundred of
/// those is the design this file exists to avoid — so without an offset the
/// whole garden would lean the same way at the same instant and pulse like a
/// heartbeat. [phaseOf] takes it from the session that grew the plant, through
/// the domain's [stableFraction], which means it is decided once and never
/// re-rolled: a garden scrolled away from and back comes back mid-lean where it
/// was, rather than snapping to a new arrangement.
final class PlantSway {
  const PlantSway._();

  /// §5.3: one full sway, out and back.
  static const Duration period = Duration(seconds: 4);

  /// §5.3: 2° of rotation at the extremes of the sway, in radians.
  ///
  /// Small enough that it reads as air moving rather than as weather, and small
  /// enough that a leaning plant still covers the plot it is standing on.
  static const double amplitude = 2 * math.pi / 180;

  /// Where in the loop the plant identified by [seed] is, as a fraction of a
  /// period, so that no two neighbours lean together.
  ///
  /// **The seed is the plant's session where it has one.** That is what
  /// [GrowingPlant] leans on, and using anything else in the garden would give
  /// the plant a user watched grow a different phase the moment they went and
  /// looked at it. REQ-021's bonus plants were awarded rather than grown, have
  /// no session and never appear on the timer screen, so they seed from their
  /// own id — which the caller passes and this does not have to know about.
  static double phaseOf(String seed) => stableFraction(seed);

  /// How far the plant identified by [seed] is leaning, in radians, when the
  /// shared loop is [turn] fractions of a period through.
  ///
  /// [turn] runs 0 to 1 and wraps; a sine does not care that it does, so a
  /// controller repeating over that range is a continuous motion with no seam at
  /// the wrap.
  ///
  /// A sine rather than a curve applied to a ramp, for the reason [GrowingPlant]
  /// gives: the sway has no start and no end to ease between, and a sine is
  /// already slowest at its extremes, which is what §5.3's ease-in-out is asking
  /// for.
  ///
  /// [amount] scales the whole lean, 0 to 1. It is how a plant that has just
  /// matured drifts into the motion instead of snapping into it — its phase puts
  /// it somewhere in the middle of a swing the moment it appears — and it is
  /// also the dial a reduce-motion setting turns to zero.
  static double leanAt(
    double turn, {
    required String seed,
    double amount = 1,
  }) =>
      math.sin((turn + phaseOf(seed)) * 2 * math.pi) * amplitude * amount;
}
