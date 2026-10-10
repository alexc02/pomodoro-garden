import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/garden/decor_sprite.dart';
import 'package:pomodoro_garden/src/garden/placeholder_decor_sprites.dart';

/// What the tests around REQ-036 bake, place and expect.
///
/// Shared rather than written out per file so that the four colours a decor
/// object is drawn in are one decision here, in the same way the harness owns
/// the fake ports: a test about depth ordering should not have to have an
/// opinion about what teak looks like.

/// The registry every test bakes decor from. The real placeholder one, because
/// what a test asserts about a footprint has to be true of the picture the app
/// actually draws.
const DecorSpriteRegistry testDecorRegistry = PlaceholderDecorSpriteRegistry();

/// Four distinguishable colours, none of them the plant palette's.
const DecorPalette testDecorPalette = DecorPalette(
  material: Color(0xFF9A9A92),
  water: Color(0xFF9EC5DE),
  shade: Color(0xFF8B6F47),
  glow: Color(0xFFE8C36B),
);

/// An item of [kind] standing in [plot].
Decor testDecor(
  DecorKind kind,
  GardenPlot plot, {
  String id = 'decor',
  DateTime? placedAt,
}) =>
    Decor(
      id: id,
      kind: kind,
      plot: plot,
      placedAt: placedAt ?? DateTime.utc(2026, 8, 11, 9, 41),
    );
