import 'dart:io';

import 'package:test/test.dart';

/// The domain core is pure Dart. Two things hold that line:
///
/// 1. This package's pubspec has no `flutter` dependency, so a Flutter import
///    is an unresolved URI, which `analysis_options.yaml` promotes to an error.
/// 2. This test, which fails with a message that says *why* rather than just
///    "target of URI doesn't exist".
///
/// Belt and braces on purpose: the pubspec check is the one that cannot be
/// worked around, and this one is the one that explains itself.
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
          'The domain core must not depend on Flutter — that separation is what '
          'lets it be tested with an injected clock and no widget binding. Move '
          'the Flutter-facing part into the app package (lib/src/...) and keep '
          'the rule here.\n${offenders.join('\n')}',
    );
  });

  test('the pubspec does not depend on Flutter', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      RegExp(r'^\s+(flutter|flutter_test):\s*$', multiLine: true)
          .hasMatch(pubspec),
      isFalse,
      reason: 'Adding `flutter` to pomodoro_domain would make every Flutter '
          'import resolve, silently dissolving the boundary this package '
          'exists to keep.',
    );
  });
}

/// `package:flutter/...`, `dart:ui` and `dart:ui_web` are all only importable
/// when the Flutter engine SDK is on the resolution path.
final _forbiddenImport = RegExp(
  r'''^\s*(import|export)\s+['"](package:flutter[/_]|dart:ui)''',
);

Iterable<File> _dartFilesUnder(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));
