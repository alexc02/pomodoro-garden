import 'dart:ui';

import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/garden/decor_sprite.dart';
import 'package:pip_garden/src/garden/placeholder_decor_sprites.dart';

// Shared decor fixtures.

const DecorSpriteRegistry testDecorRegistry = PlaceholderDecorSpriteRegistry();

/// Distinct colours, none from the plant palette.
const DecorPalette testDecorPalette = DecorPalette(
  material: Color(0xFF9A9A92),
  water: Color(0xFF9EC5DE),
  shade: Color(0xFF8B6F47),
  glow: Color(0xFFE8C36B),
);

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
