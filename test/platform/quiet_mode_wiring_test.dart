import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/quiet/channel_quiet_mode.dart';

/// Native quiet-mode wiring, checked from the Dart side. Nothing native builds
/// here, so these catch the silent failures: a channel name off by a
/// character, a missing manifest permission, or a zen rule that also silences
/// the session-end notice. Each is a string two files have to agree on.
void main() {
  late String androidPlugin;
  late String androidRule;
  late String iosPlugin;
  late String iosIntent;

  setUpAll(() {
    androidPlugin = File('android/app/src/main/kotlin/com/pipgarden/'
            'pip_garden/QuietModePlugin.kt')
        .readAsStringSync();
    androidRule = File('android/app/src/main/kotlin/com/pipgarden/'
            'pip_garden/QuietModeRule.kt')
        .readAsStringSync();
    iosPlugin = File('ios/Runner/QuietModePlugin.swift').readAsStringSync();
    iosIntent =
        File('ios/Runner/StartFocusSessionIntent.swift').readAsStringSync();
  });

  group('the one channel both platforms answer on', () {
    test('is named the same in Dart, Kotlin and Swift', () {
      const name = ChannelQuietMode.channelName;

      expect(name, 'pip_garden/quiet_mode');
      expect(androidPlugin, contains('"$name"'));
      expect(iosPlugin, contains('"$name"'));
    });

    test('carries the same five methods on all three sides', () {
      // Both sides answer every method even where one side does nothing, so
      // Dart never needs to know which phone it's on.
      for (final method in [
        ChannelQuietMode.accessMethod,
        ChannelQuietMode.requestAccessMethod,
        ChannelQuietMode.beginMethod,
        ChannelQuietMode.endMethod,
        ChannelQuietMode.takeLaunchRequestMethod,
      ]) {
        expect(androidPlugin, contains('"$method"'),
            reason: 'Android does not answer $method');
        expect(iosPlugin, contains('"$method"'),
            reason: 'iOS does not answer $method');
      }
    });

    test('the deadline Dart sends is the one the platform reads', () {
      // Untyped map: a renamed key arrives as the default, i.e. a deadline at
      // the epoch.
      expect(androidPlugin, contains('"${ChannelQuietMode.untilArgument}"'));
    });

    test('every access the platforms report is one Dart understands', () {
      // An unrecognised answer reads as "can't", which is safe but wrong. These
      // are the three the native sides send.
      for (final access in ['granted', 'denied', 'unavailable']) {
        expect(androidPlugin, contains('"$access"'));
      }
      expect(iosPlugin, contains('"byAutomation"'));
    });

    test('is reached through exactly one implementation', () {
      // A second implementation picked in Dart would pass every platform-branch
      // check and still break the one-port rule.
      final implementations = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) =>
              file.readAsStringSync().contains('implements QuietMode'))
          .map((file) => file.path)
          .toList();

      expect(implementations, ['lib/src/quiet/channel_quiet_mode.dart']);
    });
  });

  group('Android', () {
    late String manifest;

    setUpAll(() {
      manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    });

    test('declares the policy access the rule needs', () {
      // Without it the rule can't be registered and access is never granted.
      expect(manifest,
          contains('android.permission.ACCESS_NOTIFICATION_POLICY"'));
    });

    test('checks that access before using it, and can ask for it', () {
      expect(androidRule, contains('isNotificationPolicyAccessGranted'));
      expect(androidRule,
          contains('Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS'));
    });

    test('owns a zen rule rather than touching the global filter', () {
      // Since Android 15 `setInterruptionFilter` is silently turned into an
      // implicit rule the user never saw created.
      expect(androidRule, contains('addAutomaticZenRule'));
      expect(androidRule, contains('setAutomaticZenRuleState'));
      // The rule's own filter is set on the rule, which is fine and necessary.
      // Setting the filter on the rule is fine; on the notification manager it
      // isn't.
      expect(
        RegExp(r'\bnotifications\s*\.\s*setInterruptionFilter')
            .hasMatch(androidRule),
        isFalse,
        reason: 'The device\'s interruption filter is not this app\'s to set. '
            'Everything happens through the rule it owns.',
      );
    });

    test('lets its own end-of-session notice through its own silence', () {
      // Both halves are needed: the rule allows reminders, and the completion
      // notice is posted as a reminder.
      expect(androidRule, contains('allowReminders(true)'));
      // Total silence would swallow the notice too.
      expect(androidRule, contains('INTERRUPTION_FILTER_PRIORITY'));
      // Checked against code only; the comments mention it.
      expect(_code(androidRule), isNot(contains('INTERRUPTION_FILTER_NONE')));
      expect(
        File('lib/src/notifications/local_session_notifications.dart')
            .readAsStringSync(),
        contains('AndroidNotificationCategory.reminder'),
      );
    });

    test('holds a deadline nothing of this app has to be alive to keep', () {
      // The only part that survives the process being killed: an alarm set at
      // session start and a receiver that turns the rule off.
      expect(androidRule, contains('AlarmManager'));
      expect(androidRule, contains('QuietModeReceiver'));
      expect(manifest, contains('android:name=".QuietModeReceiver"'));
      expect(
        File('android/app/src/main/kotlin/com/pipgarden/pip_garden/'
                'QuietModeReceiver.kt')
            .readAsStringSync(),
        contains('QuietModeRule(context.applicationContext).end()'),
      );
    });

    test('registers the plugin with the engine', () {
      // An unregistered plugin looks exactly like a phone without quiet mode.
      expect(
        File('android/app/src/main/kotlin/com/pipgarden/pip_garden/'
                'MainActivity.kt')
            .readAsStringSync(),
        contains('QuietModePlugin('),
      );
    });
  });

  group('iOS', () {
    test('exposes an App Intent that opens the app to run', () {
      // The intent brings the app forward; the session has to start in the app,
      // not in a Shortcuts process.
      expect(iosIntent, contains(': AppIntent'));
      expect(iosIntent, contains('openAppWhenRun'));
      expect(iosIntent, contains('QuietModePlugin.requestSession()'));
    });

    test('puts the intent where the user will find it', () {
      // Without an `AppShortcutsProvider` it's in Shortcuts but not Siri.
      expect(iosIntent, contains('AppShortcutsProvider'));
      expect(iosIntent, contains(r'\(.applicationName)'));
    });

    test('calls the intent what the app tells the user to look for', () {
      // The settings recipe tells the user to look for this name.
      const title = 'Start a focus session';

      expect(iosIntent, contains('title: LocalizedStringResource = "$title"'));
      expect(
        File('lib/src/features/settings/settings_screen.dart')
            .readAsStringSync(),
        contains('"$title"'),
      );
    });

    test('builds both new files into the app target', () {
      // On disk isn't the same as compiled; a missing intent just never appears
      // in Shortcuts.
      final project =
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

      for (final file in [
        'QuietModePlugin.swift',
        'StartFocusSessionIntent.swift',
      ]) {
        expect(
          RegExp('isa = PBXBuildFile; fileRef = \\w+ '
                  '/\\* ${RegExp.escape(file)} ')
              .allMatches(project),
          hasLength(1),
          reason: '$file is not built into the Runner target.',
        );
      }
    });

    test('registers the plugin with the engine', () {
      expect(
        File('ios/Runner/AppDelegate.swift').readAsStringSync(),
        contains('QuietModePlugin.register(with: registrar)'),
      );
    });
  });
}

/// [source] with comment lines removed, so "API not used" checks aren't
/// fooled by comments that mention it.
String _code(String source) => source
    .split('\n')
    .where((line) {
      final trimmed = line.trimLeft();
      return !trimmed.startsWith('//') &&
          !trimmed.startsWith('*') &&
          !trimmed.startsWith('/*');
    })
    .join('\n');
