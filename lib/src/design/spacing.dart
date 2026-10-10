import 'package:flutter/widgets.dart';

/// The spacing scale. Every gap, pad and inset in the app is one of these.
///
/// A 4pt base with a roughly-doubling ramp: small enough to tune dense rows,
/// coarse enough that layouts stay on a visible rhythm.
abstract final class Spacing {
  /// 4 — hairline separation inside a component.
  static const double xs = 4;

  /// 8 — between tightly related elements, e.g. an icon and its label.
  static const double sm = 8;

  /// 16 — the default. Screen edge padding and the gap between cards.
  static const double md = 16;

  /// 24 — between sections of a screen.
  static const double lg = 24;

  /// 32 — around a focal element such as the timer ring.
  static const double xl = 32;

  /// 48 — full-screen breathing room; empty states and onboarding.
  static const double xxl = 48;

  /// The standard horizontal inset from the screen edge.
  static const EdgeInsets screenPadding = EdgeInsets.all(md);
}

/// The corner-radius scale. Rounded throughout — it is the shape half of the
/// same "warm and friendly" brief that picked a rounded typeface.
abstract final class Radii {
  /// 8 — chips, small buttons, inline badges.
  static const double sm = 8;

  /// 16 — cards and sheets, the default.
  static const double md = 16;

  /// 24 — large surfaces: the garden viewport, modal sheets.
  static const double lg = 24;

  /// Fully round. Large enough to pill any realistic control height.
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Icon sizes. Separate from [Spacing] because an icon's size is a type-scale
/// decision, not a rhythm one.
abstract final class IconSizes {
  /// 64 — a screen's focal illustration-in-lieu-of-art.
  static const double hero = 64;

  /// 18 — an icon inside a control, beside its own label. A chip's avatar.
  static const double inline = 18;

  /// 12 — a mark on a control rather than part of it, small enough to be
  /// noticed second, after the label.
  static const double mark = 12;
}
