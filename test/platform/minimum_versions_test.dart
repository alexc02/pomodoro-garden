import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The minimum and target platform versions live in four files that no compiler
/// cross-checks. `flutter create` regenerates some of them, and a stale copy
/// only shows up as a store rejection or a crash on an old device — so assert
/// them here, where a wrong value fails in seconds.
///
/// Anything changed below must also change in `docs/platforms.md`.
void main() {
  const iosMinimum = '17.0';
  const androidMinSdk = 26;
  const androidTargetSdk = 36;

  group('iOS minimum is $iosMinimum', () {
    test('every build configuration in the Xcode project agrees', () {
      final project =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

      final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);')
          .allMatches(project)
          .map((match) => match.group(1))
          .toList();

      expect(targets, isNotEmpty, reason: 'No deployment target found at all.');
      expect(
        targets.toSet(),
        {iosMinimum},
        reason: 'Debug, Profile and Release must all be $iosMinimum.',
      );
    });

    test('the Podfile pins pods to the same minimum', () {
      final podfile = File('ios/Podfile').readAsStringSync();

      expect(podfile, contains("platform :ios, '$iosMinimum'"));
      expect(
        podfile,
        contains("config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = "
            "'$iosMinimum'"),
        reason: 'Without the post_install pin, pods build against Flutter\'s '
            'lower floor.',
      );
    });
  });

  group('Android', () {
    late String gradle;

    setUpAll(() {
      gradle = File('android/app/build.gradle.kts').readAsStringSync();
    });

    int valueOf(String key) {
      final match = RegExp('$key = (\\d+)').firstMatch(gradle);
      expect(match, isNotNull, reason: 'No literal `$key` in build.gradle.kts.');
      return int.parse(match!.group(1)!);
    }

    test('minSdk is $androidMinSdk', () {
      expect(valueOf('minSdk'), androidMinSdk);
    });

    test('targetSdk is $androidTargetSdk, the level Play requires', () {
      expect(valueOf('targetSdk'), androidTargetSdk);
    });

    test('compiles against the level it targets', () {
      expect(valueOf('compileSdk'), androidTargetSdk);
    });
  });
}
