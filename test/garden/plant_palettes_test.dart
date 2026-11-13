import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/design/garden_colors.dart';
import 'package:pip_garden/src/garden/plant_palettes.dart';

// Species of one form share a drawing, so colour is the only thing that tells
// them apart in the garden and on the shelf.

const GardenColors _garden = GardenColors.light;

HSLColor _bloom(PlantSpecies species) =>
    HSLColor.fromColor(plantPaletteIn(_garden, species).bloom);

HSLColor _foliage(PlantSpecies species) =>
    HSLColor.fromColor(plantPaletteIn(_garden, species).foliage);

/// Degrees between two hues, the short way round.
double _apart(double a, double b) {
  final gap = (a - b).abs() % 360;
  return gap > 180 ? 360 - gap : gap;
}

void main() {
  test('no two session species of one form are drawn the same', () {
    for (final form in PlantForm.values) {
      if (form.type == PlantType.bonus) continue;

      final palettes = {
        for (final species in PlantSpecies.values)
          if (species.form == form) species: plantPaletteIn(_garden, species),
      };
      expect(
        palettes.values.toSet(),
        hasLength(palettes.length),
        reason: 'two ${form.name} species share every colour',
      );
    }
  });

  test('flowers come in their own colours, not shades of one', () {
    expect(_apart(_bloom(PlantSpecies.poppy).hue, 0), lessThan(15));
    expect(_apart(_bloom(PlantSpecies.cornflower).hue, 225), lessThan(15));
    expect(_apart(_bloom(PlantSpecies.buttercup).hue, 50), lessThan(15));

    // The three that used to be a few degrees apart.
    expect(
      _apart(
        _bloom(PlantSpecies.poppy).hue,
        _bloom(PlantSpecies.cornflower).hue,
      ),
      greaterThan(90),
    );
  });

  test('a white flower is pale, and a black tulip dark', () {
    final theme = HSLColor.fromColor(_garden.bloom);

    final daisy = _bloom(PlantSpecies.daisy);
    expect(daisy.saturation, lessThan(theme.saturation * 0.3));
    expect(daisy.lightness, greaterThan(theme.lightness));

    expect(
      _bloom(PlantSpecies.blackTulip).lightness,
      lessThan(theme.lightness - 0.2),
    );
  });

  test('a plain colour keeps the brightness the season gave it', () {
    // Only the hue is the species' own, so a winter garden stays wintry.
    for (final garden in [
      _garden,
      _garden.copyWith(bloom: const Color(0xFF9AA7B0)),
    ]) {
      final theme = HSLColor.fromColor(garden.bloom);
      final poppy =
          HSLColor.fromColor(plantPaletteIn(garden, PlantSpecies.poppy).bloom);

      expect(poppy.saturation, closeTo(theme.saturation, 0.01));
      expect(poppy.lightness, closeTo(theme.lightness, 0.01));
    }
  });

  test('a ginkgo is known by its gold leaves', () {
    expect(_apart(_foliage(PlantSpecies.ginkgo).hue, 50), lessThan(15));
    expect(
      _apart(
        _foliage(PlantSpecies.ginkgo).hue,
        _foliage(PlantSpecies.maple).hue,
      ),
      greaterThan(30),
    );
  });

  test('milestone plants keep the theme bloom, nudged', () {
    final theme = HSLColor.fromColor(_garden.bloom);
    for (final species in PlantSpecies.of(PlantType.bonus)) {
      expect(
        _apart(_bloom(species).hue, theme.hue),
        lessThanOrEqualTo(12.5),
        reason: species.name,
      );
    }
  });

  test('what grows only in winter is in leaf in winter', () {
    for (final species in PlantSpecies.values) {
      if (species.season != Season.winter) continue;
      expect(evergreens, contains(species), reason: species.name);
    }
  });
}
