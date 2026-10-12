import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Dart talks to one live-surface port; platform differences live in native
// code behind it. Enforced because the violation is always one innocent
// `if (Platform.isAndroid)` in a view. Only files whose job is a platform's
// answer to something may check the platform.
void main() {
  test('no view, session or live-surface code branches on the platform', () {
    final offenders = <String>[];

    for (final file in _dartFilesUnder('lib')) {
      if (_mayKnowThePlatform(file.path)) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Only code counts.
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (lines[i].trimLeft().startsWith('///')) continue;
        if (_platformCheck.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'The live session surface is one Dart port with two native '
          'implementations behind it. Anything that differs between the two '
          'phones is the platform\'s answer to the same question, and belongs '
          'in LiveSessionService.kt or LiveSessionWidget.swift rather than in '
          'a branch here.\n${offenders.join('\n')}',
    );
  });

  test('the live surface is reached through exactly one provider', () {
    // A second implementation picked in Dart would break the same rule.
    final directory = Directory('lib/src/live');
    expect(directory.existsSync(), isTrue);

    final implementations = _dartFilesUnder('lib')
        .where((file) => file.readAsStringSync().contains(
              'implements LiveSessionSurface',
            ))
        .map((file) => file.path)
        .toList();

    expect(
      implementations,
      ['lib/src/live/channel_live_session_surface.dart'],
      reason: 'One implementation, over one method channel. Two would mean the '
          'choice between them is made in Dart.',
    );
  });
}

/// Files allowed to check the platform. Notifications ask for permission and
/// install sounds differently per platform. The live surface's channel
/// implementation is deliberately not here.
bool _mayKnowThePlatform(String path) =>
    path.contains('lib/src/notifications/local_session_notifications.dart');

/// Deliberately broad: a false positive costs one line in
/// [_mayKnowThePlatform].
final _platformCheck = RegExp(
  r'\b('
  r'Platform\.(is|operatingSystem)'
  r'|defaultTargetPlatform'
  r'|TargetPlatform\.'
  r'|kIsWeb'
  r')',
);

Iterable<File> _dartFilesUnder(String path) => Directory(path)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    // Skip generated code.
    .where((file) => !file.path.endsWith('.g.dart'));
