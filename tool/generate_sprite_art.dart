import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'sprite_art/decor.dart';
import 'sprite_art/flower.dart';
import 'sprite_art/plants.dart';
import 'sprite_art/wash.dart';

/// Paints the paper-cut sprites into `assets/art/`, and updates their rows in
/// the manifest.
///
///     flutter test tool/generate_sprite_art.dart
///
/// PRD v2.2 §9.1: there is no illustrator, so the art is generated here, in the
/// paper-cut style the owner chose in ticket 28. This is ticket 28's one-plant
/// test: it paints the **flower** only and leaves the
/// other types' placeholder rows from `tool/generate_art.dart` alone. Ticket 35
/// adds the rest to [_painters].
///
/// Like `tool/generate_art.dart`, it lives in `tool/` so that `flutter test`
/// does not run it on its way past: it writes files.

/// Which plant types this generator owns, and how each is painted.
final Map<PlantType, Future<void> Function(Sheet, GrowthStage)> _painters = {
  PlantType.wildflower: paintWildflower,
  PlantType.herb: paintHerb,
  PlantType.flower: paintFlower,
  PlantType.bush: paintBush,
  PlantType.smallTree: paintSmallTree,
  PlantType.largeTree: paintLargeTree,
  PlantType.bonus: paintBonus,
};

const int _side = 512;

/// Which finish to paint in. Paper-cut is the app's style (ticket 28); set
/// `FINISH=watercolour` or `FINISH=flat` to see the two it was chosen over.
final Finish _finish = Finish.values.byName(
  Platform.environment['FINISH'] ?? Finish.paperCut.name,
);
const String _directory = 'assets/art';

void main() {
  test('paint the sprites', () async {
    final manifestFile = File('$_directory/manifest.json');
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
    final rows = [
      for (final row in manifest['plants']! as List<Object?>)
        row! as Map<String, Object?>,
    ];

    for (final MapEntry(key: type, value: paint) in _painters.entries) {
      for (final stage in GrowthStage.values) {
        final name = '${type.name}_${stage.name}';
        final sheet = Sheet(_side, finish: _finish);
        await paint(sheet, stage);

        final art = '$_directory/plants/$name.png';
        final roles = '$_directory/plants/$name.roles.png';
        final footprint = sheet.write(art: art, mask: roles);

        final row = rows.firstWhere(
          (it) => it['type'] == type.name && it['stage'] == stage.name,
        );
        row
          ..['art'] = art
          ..['roles'] = roles
          ..['footprint'] = footprint;
      }
    }

    final decorRows = [
      for (final row in manifest['decor']! as List<Object?>)
        row! as Map<String, Object?>,
    ];
    for (final kind in DecorKind.values) {
      final sheet = Sheet(_side, finish: _finish);
      await paintDecor(sheet, kind);

      final art = '$_directory/decor/${kind.name}.png';
      final roles = '$_directory/decor/${kind.name}.roles.png';
      final footprint = sheet.write(art: art, mask: roles);

      decorRows.firstWhere((it) => it['kind'] == kind.name)
        ..['art'] = art
        ..['roles'] = roles
        ..['footprint'] = footprint;
    }

    manifest
      ..['decor'] = decorRows
      ..['note'] = 'Every plant and object is paper-cut art, painted by '
          'tool/generate_sprite_art.dart (PRD v2.2 §9.1, ticket 35). '
          'See docs/art-pipeline.md.'
      ..['plants'] = rows;
    manifestFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
  });
}
