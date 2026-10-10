import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_garden/src/live/channel_live_session_surface.dart';

/// The platform half of ticket 08, asserted from the only side that can be run
/// here.
///
/// None of the Swift or the Kotlin compiles on this machine, and no device or
/// emulator exists to run it on — so the failures these tests exist to catch
/// are the *silent* ones. A channel name that differs by a character between
/// Dart and Kotlin is a live surface that never appears, with nothing in any
/// log to say why. A widget extension left out of the Xcode project is a Live
/// Activity that cannot start. A foreground service without its type declared
/// is a crash on Android 14, on launch of the first session.
///
/// Every one of those is a string in two files that have to agree, which is
/// exactly the thing a test can hold together and a reviewer cannot.
void main() {
  group('the channel both platforms answer on', () {
    late String androidPlugin;
    late String iosPlugin;

    setUpAll(() {
      androidPlugin = File('android/app/src/main/kotlin/com/pomodorogarden/'
              'pomodoro_garden/LiveSessionSurfacePlugin.kt')
          .readAsStringSync();
      iosPlugin =
          File('ios/Runner/LiveSessionSurfacePlugin.swift').readAsStringSync();
    });

    test('is named the same in Dart, Kotlin and Swift', () {
      const name = ChannelLiveSessionSurface.channelName;

      expect(name, 'pomodoro_garden/live_session');
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
      // The list below is the fixed point the two native sides are checked
      // against, so it has to be checked against Dart itself or it is only a
      // record of what someone once believed.
      final sent = RegExp("'([a-zA-Z]+)': session")
          .allMatches(File('lib/src/live/channel_live_session_surface.dart')
              .readAsStringSync())
          .map((match) => match.group(1)!)
          .toList();

      expect(sent, _sentToThePlatform);
    });

    test('every argument Dart sends is read by at least one platform', () {
      // The map is untyped on both sides of every channel, so a renamed key is
      // a field that silently arrives as its default — a countdown at the
      // epoch, a plant with no name. Nothing here catches that; this does.
      //
      // "At least one" rather than both, because the two surfaces are not the
      // same drawing: iOS picks a glyph by `stageIndex` where Android writes
      // `stageLabel` beside the species, and iOS needs `sessionId` to tell
      // updating one activity apart from starting another where Android posts
      // over one notification id. A key neither reads is a key nobody meant to
      // send.
      for (final key in _sentToThePlatform) {
        expect(
          androidPlugin.contains('"$key"') || iosPlugin.contains('"$key"'),
          isTrue,
          reason: '$key is sent and neither platform reads it',
        );
      }
    });

    test('the session itself is read by both', () {
      // The four that are the session rather than a way of drawing it. If
      // either platform stops reading one of these, that platform's surface is
      // wrong about the timer — which is the whole failure this ticket exists
      // to avoid.
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
      // From Android 14 a foreground service with no declared type is a crash
      // at `startForeground`, not a warning — and the first session the user
      // ever starts is where it would happen.
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
      // `singleTop` is what makes a tap arrive at `onNewIntent` on the running
      // activity rather than stacking a second copy of the app on top of the
      // first — which the user would see as their garden opening twice.
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
      // Without this key iOS refuses every `Activity.request`, and the refusal
      // is a thrown error inside a Task nobody is awaiting.
      expect(info, contains('<key>NSSupportsLiveActivities</key>'));
    });

    test('the widget extension is a target of the Xcode project', () {
      // The Swift files existing on disk is not the same as their being built.
      expect(project, contains('/* LiveSessionWidget */'));
      expect(project, contains('com.apple.product-type.app-extension'));
      expect(project, contains('LiveSessionWidget.appex'));
    });

    test('the extension is embedded in the app that ships it', () {
      // An extension built but not embedded is an extension that does not
      // install — and `dstSubfolderSpec = 13` is the PlugIns directory it has
      // to be copied into.
      expect(project, contains('Embed Foundation Extensions'));
      expect(project, contains('dstSubfolderSpec = 13;'));
    });

    test('the attributes are compiled into both targets', () {
      // An `ActivityAttributes` type is matched between app and extension by
      // its shape. One membership rather than two is an activity that starts
      // and never appears.
      //
      // Counted as `PBXBuildFile` entries rather than as mentions: one build
      // file is one target membership, where the name appears again in every
      // phase that lists it.
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

/// The keys `ChannelLiveSessionSurface.show` puts in its argument map.
///
/// Written out rather than scraped out of the Dart source, because the point of
/// the test that reads it is to catch a key changing on one side only — and a
/// list that regenerated itself from that same side would agree with every
/// change it was meant to catch.
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
