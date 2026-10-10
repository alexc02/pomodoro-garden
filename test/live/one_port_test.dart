import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ticket 08's last criterion, and the one a test has to keep because nothing
/// else can: **Dart code talks to one port; platform specifics live behind it.**
///
/// The rule is worth enforcing rather than reviewing because the violation is
/// always a single plausible-looking line. Android has no Dynamic Island, so the
/// tempting fix for anything that behaves differently is
/// `if (Platform.isAndroid)` at the point of difference — and the point of
/// difference is usually in a view. One of those and the surface is half in Dart
/// and half native on each platform, and REQ-010 and REQ-011 have become two
/// features that have to be kept in step by hand.
///
/// Kept narrow on purpose. This is not "no Dart may ever know what platform it
/// is on"; it is that **no view, no session code and no domain code may**. The
/// files allowed to know are the ones whose whole job is a platform's answer to
/// something.
void main() {
  test('no view, session or live-surface code branches on the platform', () {
    final offenders = <String>[];

    for (final file in _dartFilesUnder('lib')) {
      if (_mayKnowThePlatform(file.path)) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Comments discuss the two platforms constantly — that is most of what
        // this ticket's comments are about. Only code counts.
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
    // The other half: an override point that exists, and one of it. A second
    // implementation chosen in Dart would satisfy the test above and break the
    // same rule.
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

/// The files whose job is a platform's answer to something.
///
/// One, and it earns it: the notification implementation asks each platform for
/// permission in the way that platform asks, dresses a notice the way that
/// platform dresses one, and installs a sound where only one of the two needs
/// it installed. It is not a *view*, and it does not decide what the user is
/// offered — only how the same thing is asked for.
///
/// The two audio files used to be here, for picking an iOS audio category and
/// an Android usage. Ticket 10 moved that decision into `AppAudioSession`, which
/// asks for a *use* and lets `audio_session` express it on both — so
/// `end_sound_player.dart` and `bundled_end_sound_player.dart` name no platform
/// at all any more, and this list got shorter rather than being renamed.
///
/// `channel_live_session_surface.dart` is deliberately **not** on this list. It
/// is the live surface's implementation and it still may not branch: both
/// native sides answer the same channel, which is the whole design.
bool _mayKnowThePlatform(String path) =>
    path.contains('lib/src/notifications/local_session_notifications.dart');

/// Every way Dart offers to ask which phone this is.
///
/// Deliberately broad. A false positive is a one-line change to
/// [_mayKnowThePlatform] with a reason attached; a false negative is the two
/// surfaces quietly drifting apart.
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
    // Generated code is not written by anyone and is not anyone's to fix.
    .where((file) => !file.path.endsWith('.g.dart'));
