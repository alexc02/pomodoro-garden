import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/design/garden_colors.dart';
import 'package:pomodoro_garden/src/design/garden_skin.dart';
import 'package:pomodoro_garden/src/export/garden_exporter.dart';
import 'package:pomodoro_garden/src/features/journal/journal_paper.dart';
import 'package:pomodoro_garden/src/garden/art_bundle.dart';
import 'package:pomodoro_garden/src/garden/garden_atlas.dart';
import 'package:pomodoro_garden/src/garden/garden_atlas_recipe.dart';

/// The Play Store feature graphic (PRD §6.1, §9.1), 1024 × 500.
///
///     flutter test tool/generate_store_art.dart
///
/// A spring garden in the Zen theme, drawn by the app's own export path, on a
/// paper sky. No text: Play shows the app's name beside the graphic, and text
/// in it is cut off on some surfaces. Written to `docs/store/`, outside the
/// app bundle, because it ships to the store and not in the app.
///
/// The screenshots are not made here: the owner takes them from the iOS
/// Simulator and the Android emulator (PRD v2.2 §6.3).
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
      // Transparent, so the garden sits straight on the paper sky below rather
      // than on a box of its own.
      sky: const Color(0x00000000),
    );
    atlas.dispose();

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(Offset.zero & _size, Paint()..color = colours.skyDay);
    PaperPainter(fibre: colours.textSecondary, wash: colours.soil)
        .paint(canvas, _size);

    // The garden, as large as fits with a margin, a little below centre so it
    // sits on the bottom of the frame like a picture on a table.
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

/// Sixty plants of every type, with a bonus plant among them.
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
