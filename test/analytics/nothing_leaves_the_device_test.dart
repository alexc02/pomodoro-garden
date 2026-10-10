import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PRD §7.2, as a test rather than as an intention.
///
/// "No analytics provider. No SDK, no network, no account" is the kind of
/// promise that is true on the day it is written and quietly false two tickets
/// later, because the line that breaks it looks reasonable on its own — one
/// crash reporter, one `http` dependency for one lookup. It is also a promise
/// the app makes in public: Apple's privacy labels and Play's Data Safety form
/// both say *nothing is collected*, and a filing that stopped being true is a
/// worse problem than a bug.
///
/// So the two halves are pinned here. Neither test is about analytics code
/// specifically — the promise is about the whole app, and an event log is only
/// private if there is nothing else on the device that could send it anywhere.
void main() {
  test('the app depends on no third-party SDK that could phone home', () {
    // Every runtime dependency, listed rather than pattern-matched: what makes
    // this test worth having is that adding one has to be a deliberate edit
    // *here*, with §7.2 in front of whoever is making it.
    //
    // Each of these is either Flutter itself, this app's own domain core, or a
    // package that talks to the device — a database file, a notification, an
    // audio session. None of them has a server.
    const known = {
      'flutter',
      'pomodoro_domain',
      'flutter_riverpod',
      'cupertino_icons',
      'drift',
      'path_provider',
      'path',
      'sqlite3',
      'flutter_local_notifications',
      'timezone',
      'just_audio',
      'audio_session',
    };

    // **Nothing in this list reaches a server.** It was once three entries
    // longer: `in_app_purchase` and its two platform packages, which talked to
    // StoreKit and Play Billing to take a payment. The app is free and they are
    // gone, so §7.2's promise no longer needs the paragraph of justification
    // that used to sit here — every package above talks to this device and to
    // nothing else. See `docs/adr/0021-…`.

    expect(
      _dependenciesOf('pubspec.yaml'),
      known,
      reason: 'PRD §7.2: no third-party analytics SDK, and nothing that carries '
          'anything about the user off this device. A package added here has to '
          'be one that talks to this device, and the privacy labels, the Data '
          'Safety form and the privacy policy all have to stay true of it. If '
          'it does, add it to this set with the reason.',
    );
  });

  test('nothing in the app opens a network connection', () {
    final offenders = <String>[];

    for (final file in _dartFilesUnder('lib')
        .followedBy(_dartFilesUnder('packages/pomodoro_domain/lib'))) {
      // Generated code is drift's, and its own dependency is checked above.
      if (file.path.endsWith('.g.dart')) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Comments say "no network call is made" in several places, and that
        // sentence is not a network call.
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (lines[i].trimLeft().startsWith('///')) continue;
        if (_reachesOffDevice.hasMatch(lines[i])) {
          offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'PRD §7.2: the §7.1 events, and everything else on this device, '
          'stay on it. The only network calls v1 may ever make are the store '
          "SDKs' at purchase time, which are the platform's rather than this "
          "app's.",
    );
  });
}

/// The names under `dependencies:` in [path].
///
/// Parsed by indentation rather than with a YAML package, for the reason the
/// rest of this suite avoids new dependencies: a test about not adding
/// dependencies should not add one.
Set<String> _dependenciesOf(String path) {
  final names = <String>{};
  var inDependencies = false;

  for (final line in File(path).readAsLinesSync()) {
    if (line.startsWith('dependencies:')) {
      inDependencies = true;
      continue;
    }
    // Any other top-level key ends the section — `dev_dependencies:` included,
    // which is deliberately not covered: a test-time package ships to nobody.
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
      inDependencies = false;
    }
    if (!inDependencies) continue;

    // A dependency is a key at exactly one level of indentation. Anything
    // deeper is that dependency's own settings — `sdk: flutter`, `path: …`.
    final name = RegExp(r'^  (\w+):').firstMatch(line)?.group(1);
    if (name != null) names.add(name);
  }

  return names;
}

Iterable<File> _dartFilesUnder(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

/// The ways Dart code reaches something that is not this device.
///
/// Word-bounded, so `Socket` does not match a comment about sockets and
/// `WebSocket` in a string is still caught — the point is that any of these
/// appearing in this app at all is worth a conversation.
final _reachesOffDevice = RegExp(
  r'\b(HttpClient|HttpServer|Socket|WebSocket|RawDatagramSocket|'
  r'InternetAddress|SecureSocket)\b|'
  r"import 'package:(http|dio|web_socket_channel|firebase_\w+|"
  r'amplitude_\w+|mixpanel_\w+|sentry_\w+|posthog_\w+)',
);
