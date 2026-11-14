import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import 'sprite_art/decor.dart';
import 'sprite_art/flower.dart';
import 'sprite_art/forms.dart';
import 'sprite_art/plants.dart';
import 'sprite_art/wash.dart';

/// Paints the paper-cut sprites into `assets/art/` and updates their manifest
/// rows.
///
///     flutter test tool/generate_sprite_art.dart
///
/// Lives in `tool/` so `flutter test` doesn't run it (it writes files).

final Map<PlantForm, Future<void> Function(Sheet, GrowthStage)> _painters = {
  PlantForm.posy: paintWildflower,
  PlantForm.spire: paintSpire,
  PlantForm.leafy: paintHerb,
  PlantForm.sprig: paintSprig,
  PlantForm.rayed: paintFlower,
  PlantForm.cup: paintCupFlower,
  PlantForm.mound: paintBush,
  PlantForm.spiked: paintSpikedBush,
  PlantForm.orchard: paintSmallTree,
  PlantForm.spreading: paintSpreadingTree,
  PlantForm.broadleaf: paintLargeTree,
  PlantForm.weeping: paintWeepingTree,
  PlantForm.conifer: paintConifer,
  PlantForm.tassel: paintBonus,
};

/// Forms of one type are the same plant until the young stage, so they share
/// one file for these and the app decodes it once.
const Set<GrowthStage> _sharedByType = {GrowthStage.seed, GrowthStage.sprout};

const int _side = 512;

/// Set `FINISH=watercolour` or `FINISH=flat` to try the alternatives.
final Finish _finish = Finish.values.byName(
  Platform.environment['FINISH'] ?? Finish.paperCut.name,
);
const String _directory = 'assets/art';

void main() {
  test('paint the sprites', () async {
    final manifestFile = File('$_directory/manifest.json');
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
    final rows = <Map<String, Object?>>[];
    final painted = <String, List<double>>{};

    for (final MapEntry(key: form, value: paint) in _painters.entries) {
      for (final stage in GrowthStage.values) {
        final name = _sharedByType.contains(stage)
            ? '${form.type.name}_${stage.name}'
            : '${form.name}_${stage.name}';
        final art = '$_directory/plants/$name.png';
        final roles = '$_directory/plants/$name.roles.png';

        // A shared stage is painted by whichever form of the type comes
        // first; every form paints the same thing for it.
        if (!painted.containsKey(name)) {
          final sheet = Sheet(_side, finish: _finish);
          await paint(sheet, stage);
          painted[name] = sheet.write(art: art, mask: roles);
        }

        rows.add({
          'form': form.name,
          'stage': stage.name,
          'art': art,
          'roles': roles,
          'footprint': painted[name],
        });
      }
    }

    // Nothing the manifest doesn't name is left behind to ship.
    final named = {
      for (final name in painted.keys) ...['$name.png', '$name.roles.png'],
    };
    for (final file in Directory('$_directory/plants').listSync()) {
      if (!named.contains(file.uri.pathSegments.last)) file.deleteSync();
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
          'tool/generate_sprite_art.dart. '
          'See docs/art-pipeline.md.'
      ..['plants'] = rows;
    manifestFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
  });
}
