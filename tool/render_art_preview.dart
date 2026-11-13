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

/// Renders preview sheets of the art as the app shows it, for eyeballing.
///
///     flutter test tool/render_art_preview.dart
///
/// Writes to `build/art-preview/` (or `$PREVIEW_OUT`): per theme
/// and season `types-`, `decor-`, `garden-` and `weather-` sheets, plus for Zen
/// `stages-<season>.png` (tinted flower stages, the raw drawing, then the
/// placeholder) and a mature-flower close-up.
final String _out = Platform.environment['PREVIEW_OUT'] ??
    'build/art-preview';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('render the art preview', () async {
    Directory(_out).createSync(recursive: true);
    final bundle = await ArtBundle.load(rootBundle);
    final drawings = {
      for (final stage in GrowthStage.values)
        stage: await _decode('assets/art/plants/flower_${stage.name}.png'),
    };

    // Milestone effects (willow halo, golden wash) as an export draws them.
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
          .spriteFor(form: PlantForm.rayed, stage: stage)
          .paint(canvas, cell(row), plantPaletteIn(colours, kind));
    }

    // Untinted drawing.
    final raw = drawings[stage]!;
    canvas.drawImageRect(
      raw,
      Rect.fromLTWH(0, 0, raw.width.toDouble(), raw.height.toDouble()),
      cell(3),
      Paint()..filterQuality = FilterQuality.medium,
    );

    const PlaceholderPlantSpriteRegistry()
        .spriteFor(form: PlantForm.rayed, stage: stage)
        .paint(canvas, cell(4),
            plantPaletteIn(colours, PlantSpecies.sunflower));
  }

  return recorder.endRecording();
}

/// Forty plants, plus the milestone plants up to [awards] if given.
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

/// Mature sunflower at full size, to judge the finish.
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
      .spriteFor(form: PlantForm.rayed, stage: GrowthStage.mature)
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

/// One row per plant form, one column per stage.
Future<void> _saveTypes(
  String path,
  ArtBundle bundle,
  GardenColors colours,
) async {
  const cell = 160.0;
  const forms = PlantForm.values;
  final size = Size(cell * GrowthStage.values.length, cell * forms.length);
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(Offset.zero & size, Paint()..color = colours.skyDay);

  for (final (row, form) in forms.indexed) {
    canvas.drawRect(
      Rect.fromLTWH(0, (row + 1) * cell - 14, size.width, 14),
      Paint()..color = colours.soil,
    );
    final species = PlantSpecies.values.firstWhere((s) => s.form == form);
    for (final stage in GrowthStage.values) {
      bundle.plants.spriteFor(form: form, stage: stage).paint(
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

/// Garden with the season's weather frozen mid-fall.
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
