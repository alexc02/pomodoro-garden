import 'package:flutter/widgets.dart';

/// Spacing scale on a 4pt base.
abstract final class Spacing {
  static const double xs = 4;

  /// e.g. icon to label.
  static const double sm = 8;

  /// Default: screen edge padding, gap between cards.
  static const double md = 16;

  /// Between sections.
  static const double lg = 24;

  /// Around a focal element like the timer ring.
  static const double xl = 32;

  /// Empty states, onboarding.
  static const double xxl = 48;

  static const EdgeInsets screenPadding = EdgeInsets.all(md);
}

/// Corner radii.
abstract final class Radii {
  /// Chips, small buttons, badges.
  static const double sm = 8;

  /// Cards and sheets.
  static const double md = 16;

  /// Garden viewport, modal sheets.
  static const double lg = 24;

  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// Buttons. Uneven corners on purpose, to look hand-cut.
  static const BorderRadius paperSm = BorderRadius.only(
    topLeft: Radius.circular(4),
    topRight: Radius.circular(12),
    bottomRight: Radius.circular(6),
    bottomLeft: Radius.circular(10),
  );

  /// [paperSm] mirrored, for an outlined button next to a filled one.
  static const BorderRadius paperSmMirrored = BorderRadius.only(
    topLeft: Radius.circular(12),
    topRight: Radius.circular(4),
    bottomRight: Radius.circular(10),
    bottomLeft: Radius.circular(6),
  );

  /// [paperSm] at card size.
  static const BorderRadius paperMd = BorderRadius.only(
    topLeft: Radius.circular(6),
    topRight: Radius.circular(14),
    bottomRight: Radius.circular(8),
    bottomLeft: Radius.circular(12),
  );
}

/// Icon sizes.
abstract final class IconSizes {
  /// Focal icon standing in for illustration.
  static const double hero = 64;

  /// Icon inside a control next to its label; chip avatar.
  static const double inline = 18;

  /// A secondary mark on a control.
  static const double mark = 12;
}
