import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/design/garden_colors.dart';
import 'package:pip_garden/src/design/garden_skin.dart';
import 'package:pip_garden/src/export/garden_exporter.dart';
import 'package:pip_garden/src/design/paper_painter.dart';
import 'package:pip_garden/src/garden/art_bundle.dart';
import 'package:pip_garden/src/garden/garden_atlas.dart';
import 'package:pip_garden/src/garden/garden_atlas_recipe.dart';

/// Play Store feature graphic, 1024 x 500: a spring Zen garden via the export
/// path, on a paper sky. No text, since Play crops it on some surfaces.
///
///     flutter test tool/generate_store_art.dart
///
/// Screenshots aren't made here; they come from the simulator and emulator.
const String _out = 'docs/store/feature-graphic.png';
const Size _size = Size(1024, 500);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('paint the feature graphic', () async {
    final bundle = await ArtBundle.load(rootBundle);
    final colours = const GardenSkin(
      theme: GardenTheme.zen,
      season: Season.spring,
    ).applyTo(GardenColors.light);

    final atlas = GardenAtlas.bake(gardenAtlasRecipe(
      colours: colours,
      registry: bundle.plants,
      decorRegistry: bundle.decor,
    ));
    final garden = await GardenExporter.rasterise(
      layout: _garden(),
      atlas: atlas,
      // Transparent so the paper sky shows through.
      sky: const Color(0x00000000),
    );
    atlas.dispose();

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(Offset.zero & _size, Paint()..color = colours.skyDay);
    PaperPainter(fibre: colours.textSecondary, wash: colours.soil)
        .paint(canvas, _size);

    // As large as fits, with a margin.
    final source = Rect.fromLTWH(
      0,
      0,
      garden.width.toDouble(),
      garden.height.toDouble(),
    );
    final scale = (_size.height * 0.96 / source.height)
        .clamp(0.0, _size.width * 0.92 / source.width);
    final target = Rect.fromCenter(
      center: Offset(_size.width / 2, _size.height * 0.5),
      width: source.width * scale,
      height: source.height * scale,
    );
    canvas.drawImageRect(
      garden,
      source,
      target,
      Paint()..filterQuality = FilterQuality.high,
    );
    garden.dispose();

    final image = await recorder.endRecording().toImage(
          _size.width.round(),
          _size.height.round(),
        );
    final png = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    File(_out)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Sixty plants plus one bonus plant.
GardenLayout _garden() {
  const lengths = [25, 10, 30, 15, 40, 28, 55, 20, 80, 26, 45, 12];
  final occupied = <GardenPlot>{};
  final plants = <Plant>[];
  final start = DateTime.utc(2026, 4, 1, 9);

  for (var n = 0; n < 60; n++) {
    final anchor = start.add(Duration(hours: n * 5));
    final session = FocusSession(
      id: 'feature-$n',
      startedAt: anchor,
      plannedDuration: Duration(minutes: lengths[n % lengths.length]),
    ).completedAt(anchor.add(const Duration(hours: 2)));
    final plot = GardenPlots.nextFree(occupied);
    if (plot != null) occupied.add(plot);
    plants.add(Plant.fromSession(session, id: 'feature-plant-$n', plot: plot));
  }

  final bonusPlot = GardenPlots.nextFree(occupied);
  if (bonusPlot != null) {
    plants.add(Plant.forMilestone(
      Milestone.fifty,
      id: 'feature-bonus',
      plantedAt: start,
      plot: bonusPlot,
    ));
  }

  return GardenLayout.of(plants: plants, completedSessions: 60);
}
