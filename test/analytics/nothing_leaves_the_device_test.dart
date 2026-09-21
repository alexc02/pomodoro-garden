import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// No analytics SDK, no network, no account. Easy to break with one
// reasonable-looking dependency, and the store privacy labels say nothing is
// collected, so it's pinned here for the whole app.
void main() {
  test('the app depends on no third-party SDK that could phone home', () {
    // Listed explicitly so adding a dependency means editing this test. Each
    // is Flutter, the domain package, or something that only talks to the
    // device.
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

    // None of these reach a server (IAP was removed, see ADR 0005).

    expect(
      _dependenciesOf('pubspec.yaml'),
      known,
      reason: 'No third-party analytics SDK, and nothing that carries '
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
      // Generated drift code; drift itself is checked above.
      if (file.path.endsWith('.g.dart')) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Only code counts.
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
      reason: 'The analytics events, and everything else on this device, '
          'stay on it. The app makes no network calls.',
    );
  });
}

/// The names under `dependencies:` in [path]. Parsed by hand to avoid adding
/// a YAML dependency.
Set<String> _dependenciesOf(String path) {
  final names = <String>{};
  var inDependencies = false;

  for (final line in File(path).readAsLinesSync()) {
    if (line.startsWith('dependencies:')) {
      inDependencies = true;
      continue;
    }
    // Any other top-level key ends the section. dev_dependencies don't ship.
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
      inDependencies = false;
    }
    if (!inDependencies) continue;

    // Exactly one indent level; deeper keys are the dependency's settings.
    final name = RegExp(r'^  (\w+):').firstMatch(line)?.group(1);
    if (name != null) names.add(name);
  }

  return names;
}

Iterable<File> _dartFilesUnder(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'));

/// Ways Dart code can reach off the device. Matches in strings count too.
final _reachesOffDevice = RegExp(
  r'\b(HttpClient|HttpServer|Socket|WebSocket|RawDatagramSocket|'
  r'InternetAddress|SecureSocket)\b|'
  r"import 'package:(http|dio|web_socket_channel|firebase_\w+|"
  r'amplitude_\w+|mixpanel_\w+|sentry_\w+|posthog_\w+)',
);
