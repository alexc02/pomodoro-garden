import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/live/channel_live_session_surface.dart';

/// Native live-surface wiring, checked from the Dart side. Nothing native
/// builds here, so these catch the silent failures: a channel name off by a
/// character, a widget extension missing from the Xcode project, a foreground
/// service without its type (crash on Android 14). Each is a string two files
/// have to agree on.
void main() {
  group('the channel both platforms answer on', () {
    late String androidPlugin;
    late String iosPlugin;

    setUpAll(() {
      androidPlugin = File('android/app/src/main/kotlin/com/pipgarden/'
              'pip_garden/LiveSessionSurfacePlugin.kt')
          .readAsStringSync();
      iosPlugin =
          File('ios/Runner/LiveSessionSurfacePlugin.swift').readAsStringSync();
    });

    test('is named the same in Dart, Kotlin and Swift', () {
      const name = ChannelLiveSessionSurface.channelName;

      expect(name, 'pip_garden/live_session');
      expect(androidPlugin, contains('"$name"'));
      expect(iosPlugin, contains('"$name"'));
    });

    test('carries the same three methods on all three sides', () {
      for (final method in [
        ChannelLiveSessionSurface.showMethod,
        ChannelLiveSessionSurface.hideMethod,
        ChannelLiveSessionSurface.takeLaunchTapMethod,
        ChannelLiveSessionSurface.openedMethod,
      ]) {
        expect(androidPlugin, contains('"$method"'),
            reason: 'Android does not answer $method');
        expect(iosPlugin, contains('"$method"'),
            reason: 'iOS does not answer $method');
      }
    });

    test('Dart sends exactly the arguments written down here', () {
      // The list below is what the native sides are checked against, so check
      // it against Dart too.
      final sent = RegExp("'([a-zA-Z]+)': session")
          .allMatches(File('lib/src/live/channel_live_session_surface.dart')
              .readAsStringSync())
          .map((match) => match.group(1)!)
          .toList();

      expect(sent, _sentToThePlatform);
    });

    test('every argument Dart sends is read by at least one platform', () {
      // The maps are untyped, so a renamed key silently arrives as its default.
      // "At least one" platform, since the surfaces differ: iOS uses
      // `stageIndex` and `sessionId`, Android uses `stageLabel` and a fixed
      // notification id.
      for (final key in _sentToThePlatform) {
        expect(
          androidPlugin.contains('"$key"') || iosPlugin.contains('"$key"'),
          isTrue,
          reason: '$key is sent and neither platform reads it',
        );
      }
    });

    test('the session itself is read by both', () {
      // The four values that are the session itself, not how it's drawn.
      for (final key in ['paused', 'endsAt', 'remainingSeconds', 'progress']) {
        expect(androidPlugin, contains('"$key"'),
            reason: 'Android never reads $key');
        expect(iosPlugin, contains('"$key"'),
            reason: 'iOS never reads $key');
      }
    });
  });

  group('Android', () {
    late String manifest;

    setUpAll(() {
      manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    });

    test('declares the foreground service, with its type', () {
      // Since Android 14 an untyped foreground service crashes at
      // `startForeground`.
      expect(manifest, contains('android:name=".LiveSessionService"'));
      expect(manifest, contains('android:foregroundServiceType="specialUse"'));
      expect(
        manifest,
        contains('android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE'),
        reason: 'specialUse without its subtype property is rejected by Play, '
            'and the property is where the justification is written down.',
      );
    });

    test('holds the permissions that service needs', () {
      expect(manifest,
          contains('android.permission.FOREGROUND_SERVICE"'));
      expect(manifest,
          contains('android.permission.FOREGROUND_SERVICE_SPECIAL_USE"'));
    });

    test('the activity can receive a tap on the notification', () {
      // `singleTop` delivers the tap to `onNewIntent` instead of stacking a
      // second copy of the app.
      expect(manifest, contains('android:launchMode="singleTop"'));
    });
  });

  group('iOS', () {
    late String project;
    late String info;

    setUpAll(() {
      project =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      info = File('ios/Runner/Info.plist').readAsStringSync();
    });

    test('the app is allowed to start Live Activities', () {
      // Without this key every `Activity.request` throws inside an unawaited
      // Task.
      expect(info, contains('<key>NSSupportsLiveActivities</key>'));
    });

    test('the widget extension is a target of the Xcode project', () {
      // Files on disk aren't necessarily built.
      expect(project, contains('/* LiveSessionWidget */'));
      expect(project, contains('com.apple.product-type.app-extension'));
      expect(project, contains('LiveSessionWidget.appex'));
    });

    test('the extension is embedded in the app that ships it', () {
      // Built but not embedded means not installed. `dstSubfolderSpec = 13` is
      // PlugIns.
      expect(project, contains('Embed Foundation Extensions'));
      expect(project, contains('dstSubfolderSpec = 13;'));
    });

    test('the attributes are compiled into both targets', () {
      // `ActivityAttributes` is matched between app and extension by shape; if
      // it's only in one target the activity starts and never shows. Counted as
      // `PBXBuildFile` entries, one per target membership.
      final memberships = RegExp(
        r'isa = PBXBuildFile; fileRef = \w+ /\* LiveSessionAttributes\.swift ',
      ).allMatches(project);

      expect(
        memberships,
        hasLength(2),
        reason: 'LiveSessionAttributes.swift belongs to both the Runner and '
            'the LiveSessionWidget target.',
      );
    });

    test('the deep link the widget opens is one the app claims', () {
      final attributes =
          File('ios/LiveSession/LiveSessionAttributes.swift').readAsStringSync();
      final scheme = RegExp(r'scheme = "([a-z]+)"').firstMatch(attributes);

      expect(scheme, isNotNull, reason: 'no scheme found in the deep link');
      expect(
        info,
        contains('<string>${scheme!.group(1)}</string>'),
        reason: 'The widget opens a URL the app does not register, so tapping '
            'the surface would do nothing.',
      );
    });
  });
}

/// The keys `ChannelLiveSessionSurface.show` puts in its argument map. Written
/// out by hand so a key changing on one side gets caught.
const List<String> _sentToThePlatform = [
  'sessionId',
  'paused',
  'endsAt',
  'remainingSeconds',
  'progress',
  'stageIndex',
  'stageLabel',
  'speciesLabel',
];
