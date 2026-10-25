import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/design/garden_colors.dart';
import 'package:pip_garden/src/design/garden_skin.dart';
import 'package:pip_garden/src/design/season_palette.dart';
import 'package:pip_garden/src/export/garden_exporter.dart';
import 'package:pip_garden/src/garden/art_bundle.dart';
import 'package:pip_garden/src/garden/decor_sprite.dart';
import 'package:pip_garden/src/garden/garden_atlas.dart';
import 'package:pip_garden/src/garden/garden_atlas_recipe.dart';
import 'package:pip_garden/src/garden/placeholder_plant_sprites.dart';
import 'package:pip_garden/src/garden/plant_palettes.dart';
import 'package:pip_garden/src/garden/season_weather.dart';

/// Renders the art as the app will show it, for a person to judge (ticket 28).
///
///     flutter test tool/render_art_preview.dart
///
/// Writes to `.scratch/pip-garden/art-preview/`, outside the bundle: for
/// every theme and season, every type at every stage (`types-…`), the decor
/// (`decor-…`), a garden (`garden-…`) and that garden with its weather
/// (`weather-…`); and, for the Zen theme only, the flower's own sheets:
///
/// - `stages-<season>.png`: the flower at its five stages, through the real
///   palette tint, as a sunflower, a tulip and a daisy; then the bare drawing
///   untinted; then ticket 04's placeholder, for comparison.
/// - `garden-<season>.png`: a garden of forty plants rendered by the real
///   export path (`GardenExporter`), so the new flowers stand among the
///   placeholder types on today's soil and sky.
final String _out = Platform.environment['PREVIEW_OUT'] ??
    '.scratch/pip-garden/art-preview';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render the art preview', () async {
    Directory(_out).createSync(recursive: true);
    final bundle = await ArtBundle.load(rootBundle);
    final drawings = {
      for (final stage in GrowthStage.values)
        stage: await _decode('assets/art/plants/flower_${stage.name}.png'),
    };

    // REQ-021's two effects (ticket 36): the willow's halo, and the golden
    // garden's wash, as an export draws them (held still).
    for (final (name, upTo) in const [
      ('effects-willow', Milestone.fiveHundred),
      ('effects-golden', Milestone.oneThousand),
    ]) {
      final colours = const GardenSkin(
        theme: GardenTheme.zen,
        season: Season.summer,
      ).applyTo(GardenColors.light);
      final atlas = GardenAtlas.bake(gardenAtlasRecipe(
        colours: colours,
        registry: bundle.plants,
        decorRegistry: bundle.decor,
      ));
      await _saveImage(
        '$_out/$name.png',
        await GardenExporter.rasterise(
          layout: _garden(awards: upTo),
          atlas: atlas,
          sky: colours.skyDay,
        ),
      );
      atlas.dispose();
    }

    for (final theme in GardenTheme.values) {
      for (final season in Season.values) {
        final skin = GardenSkin(theme: theme, season: season);
        final colours = skin.applyTo(GardenColors.light);
        final name = '${theme.name}-${season.name}';

        if (theme == GardenTheme.zen) {
          await _save(
            '$_out/stages-${season.name}.png',
            _stages(bundle, colours, drawings),
          );
          await _saveCloseUp(
              '$_out/closeup-${season.name}.png', bundle, colours);
        }
        await _saveTypes('$_out/types-$name.png', bundle, colours);
        await _saveDecor('$_out/decor-$name.png', bundle, colours);

        final atlas = GardenAtlas.bake(gardenAtlasRecipe(
          colours: colours,
          registry: bundle.plants,
          decorRegistry: bundle.decor,
        ));
        final garden = await GardenExporter.rasterise(
          layout: _garden(),
          atlas: atlas,
          sky: colours.skyDay,
        );
        await _saveWeather(
          '$_out/weather-$name.png',
          garden,
          skin.palette.weather,
        );
        await _saveImage('$_out/garden-$name.png', garden);
        atlas.dispose();
      }
    }
  });
}

const double _cell = 200;

Picture _stages(
  ArtBundle bundle,
  GardenColors colours,
  Map<GrowthStage, Image> drawings,
) {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  const species = [
    PlantSpecies.sunflower,
    PlantSpecies.tulip,
    PlantSpecies.daisy,
  ];
  const rows = 5;
  final size = Size(_cell * GrowthStage.values.length, _cell * rows);

  canvas.drawRect(Offset.zero & size, Paint()..color = colours.skyDay);
  for (var r = 0; r < rows; r++) {
    canvas.drawRect(
      Rect.fromLTWH(0, (r + 1) * _cell - 26, size.width, 26),
      Paint()..color = colours.soil,
    );
  }

  for (final stage in GrowthStage.values) {
    final x = stage.index * _cell;
    Rect cell(int row) => Rect.fromLTWH(x + 8, row * _cell + 8, _cell - 16,
        _cell - 16 - 18);

    for (final (row, kind) in species.indexed) {
      bundle.plants
          .spriteFor(type: PlantType.flower, stage: stage)
          .paint(canvas, cell(row), plantPaletteIn(colours, kind));
    }

    // The drawing alone, with no palette: what the generator painted.
    final raw = drawings[stage]!;
    canvas.drawImageRect(
      raw,
      Rect.fromLTWH(0, 0, raw.width.toDouble(), raw.height.toDouble()),
      cell(3),
      Paint()..filterQuality = FilterQuality.medium,
    );

    const PlaceholderPlantSpriteRegistry()
        .spriteFor(type: PlantType.flower, stage: stage)
        .paint(canvas, cell(4),
            plantPaletteIn(colours, PlantSpecies.sunflower));
  }

  return recorder.endRecording();
}

/// Forty plants, most of them flowers, among every other type — and, when
/// [awards] is given, the 500 and 1000 milestone plants up to it.
GardenLayout _garden({Milestone? awards}) {
  const lengths = [25, 10, 30, 15, 26, 40, 28, 55, 27, 80];
  final occupied = <GardenPlot>{};
  final plants = <Plant>[];
  final start = DateTime.utc(2026, 9, 1, 9);

  for (var n = 0; n < 40; n++) {
    final anchor = start.add(Duration(hours: n));
    final session = FocusSession(
      id: 'preview-$n',
      startedAt: anchor,
      plannedDuration: Duration(minutes: lengths[n % lengths.length]),
    ).completedAt(anchor.add(const Duration(hours: 2)));
    final plot = GardenPlots.nextFree(occupied);
    if (plot != null) occupied.add(plot);
    plants.add(Plant.fromSession(session, id: 'preview-plant-$n', plot: plot));
  }

  for (final milestone in [Milestone.fiveHundred, Milestone.oneThousand]) {
    if (awards == null || milestone.sessions > awards.sessions) continue;
    final plot = GardenPlots.nextFree(occupied);
    if (plot != null) occupied.add(plot);
    plants.add(Plant.forMilestone(
      milestone,
      id: 'preview-${milestone.sessions}',
      plantedAt: start,
      plot: plot,
    ));
  }

  return GardenLayout.of(plants: plants, completedSessions: plants.length);
}

Future<void> _save(String path, Picture picture) async {
  final bounds = Size(_cell * GrowthStage.values.length, _cell * 5);
  final image = await picture.toImage(
    bounds.width.round(),
    bounds.height.round(),
  );
  picture.dispose();
  await _saveImage(path, image);
}

Future<void> _saveImage(String path, Image image) async {
  final png = await image.toByteData(format: ImageByteFormat.png);
  image.dispose();
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

/// The mature flower at the size it is painted, as a sunflower, so the
/// finish itself can be judged rather than its silhouette.
Future<void> _saveCloseUp(
  String path,
  ArtBundle bundle,
  GardenColors colours,
) async {
  const side = 512.0;
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, side, side),
      Paint()..color = colours.skyDay,
    );
  bundle.plants
      .spriteFor(type: PlantType.flower, stage: GrowthStage.mature)
      .paint(
        canvas,
        const Rect.fromLTWH(0, 0, side, side),
        plantPaletteIn(colours, PlantSpecies.sunflower),
      );
  final picture = recorder.endRecording();
  final image = await picture.toImage(side.round(), side.round());
  picture.dispose();
  await _saveImage(path, image);
}

Future<Image> _decode(String path) async {
  final data = await rootBundle.load(path);
  final codec = await instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// Every plant type, a row each, at its five stages: the whole set at a glance.
Future<void> _saveTypes(
  String path,
  ArtBundle bundle,
  GardenColors colours,
) async {
  const cell = 160.0;
  const types = PlantType.values;
  final size = Size(cell * GrowthStage.values.length, cell * types.length);
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(Offset.zero & size, Paint()..color = colours.skyDay);

  for (final (row, type) in types.indexed) {
    canvas.drawRect(
      Rect.fromLTWH(0, (row + 1) * cell - 14, size.width, 14),
      Paint()..color = colours.soil,
    );
    final species = PlantSpecies.values.firstWhere((s) => s.type == type);
    for (final stage in GrowthStage.values) {
      bundle.plants.spriteFor(type: type, stage: stage).paint(
            canvas,
            Rect.fromLTWH(stage.index * cell + 4, row * cell + 4, cell - 8,
                cell - 8 - 10),
            plantPaletteIn(colours, species),
          );
    }
  }

  final picture = recorder.endRecording();
  final image =
      await picture.toImage(size.width.round(), size.height.round());
  picture.dispose();
  await _saveImage(path, image);
}

/// REQ-040's four objects, dressed as the garden dresses them.
Future<void> _saveDecor(
  String path,
  ArtBundle bundle,
  GardenColors colours,
) async {
  const cell = 220.0;
  final size = Size(cell * DecorKind.values.length, cell);
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(Offset.zero & size, Paint()..color = colours.skyDay)
    ..drawRect(
      Rect.fromLTWH(0, cell - 16, size.width, 16),
      Paint()..color = colours.soil,
    );
  final palette = DecorPalette(
    material: colours.decor,
    water: colours.skyDay,
    shade: colours.soil,
    glow: colours.bloom,
  );
  for (final (i, kind) in DecorKind.values.indexed) {
    bundle.decor.spriteFor(kind).paint(
          canvas,
          Rect.fromLTWH(i * cell + 6, 6, cell - 12, cell - 12 - 10),
          palette,
        );
  }
  final picture = recorder.endRecording();
  final image =
      await picture.toImage(size.width.round(), size.height.round());
  picture.dispose();
  await _saveImage(path, image);
}

/// The garden with the season's weather falling over it, frozen mid-fall.
Future<void> _saveWeather(String path, Image garden, Weather? weather) async {
  final size = Size(garden.width.toDouble(), garden.height.toDouble());
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder)..drawImage(garden, Offset.zero, Paint());
  if (weather != null) {
    WeatherPainter(
      falling: ValueNotifier<double>(2.5),
      layers: [(weather: weather, alpha: 1)],
    ).paint(canvas, size);
  }
  final picture = recorder.endRecording();
  final image =
      await picture.toImage(size.width.round(), size.height.round());
  picture.dispose();
  await _saveImage(path, image);
}
