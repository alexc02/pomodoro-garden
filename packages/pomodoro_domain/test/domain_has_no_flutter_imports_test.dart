import 'dart:io';

import 'package:test/test.dart';

/// Backs up the pubspec (no `flutter` dependency) with a failure message
/// that actually explains the rule.
void main() {
  test('no library under lib/ imports Flutter', () {
    final offenders = <String>[];

    for (final file in _dartFilesUnder('lib')) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (_forbiddenImport.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'The domain core must not depend on Flutter. Move the Flutter part '
          'into the app package (lib/src/...).\n${offenders.join('\n')}',
    );
  });

  test('the pubspec does not depend on Flutter', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      RegExp(r'^\s+(flutter|flutter_test):\s*$', multiLine: true)
          .hasMatch(pubspec),
      isFalse,
      reason: 'With `flutter` in the pubspec, Flutter imports would resolve '
          'and the boundary would quietly disappear.',
    );
  });
}

/// Only resolvable with the Flutter engine SDK.
final _forbiddenImport = RegExp(
  r'''^\s*(import|export)\s+['"](package:flutter[/_]|dart:ui)''',
);

Iterable<File> _dartFilesUnder(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));
