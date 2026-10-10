import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_garden/src/quiet/channel_quiet_mode.dart';

/// The platform half of ticket 11, asserted from the only side that can be run
/// here.
///
/// None of the Kotlin or the Swift compiles on this machine, and no device or
/// emulator exists to run it on — so what these tests catch are the *silent*
/// failures. A channel name that differs by a character is a quiet mode that
/// never happens, with nothing in any log to say why. A missing manifest
/// permission is a switch the user can turn on that does nothing. A zen rule
/// that silences everything is an app that turns the phone quiet and then fails
/// to tell the user their session finished.
///
/// Every one of those is a string in two files that have to agree, which is
/// exactly the thing a test can hold together and a reviewer cannot.
void main() {
  late String androidPlugin;
  late String androidRule;
  late String iosPlugin;
  late String iosIntent;

  setUpAll(() {
    androidPlugin = File('android/app/src/main/kotlin/com/pomodorogarden/'
            'pomodoro_garden/QuietModePlugin.kt')
        .readAsStringSync();
    androidRule = File('android/app/src/main/kotlin/com/pomodorogarden/'
            'pomodoro_garden/QuietModeRule.kt')
        .readAsStringSync();
    iosPlugin = File('ios/Runner/QuietModePlugin.swift').readAsStringSync();
    iosIntent =
        File('ios/Runner/StartFocusSessionIntent.swift').readAsStringSync();
  });

  group('the one channel both platforms answer on', () {
    test('is named the same in Dart, Kotlin and Swift', () {
      const name = ChannelQuietMode.channelName;

      expect(name, 'pomodoro_garden/quiet_mode');
      expect(androidPlugin, contains('"$name"'));
      expect(iosPlugin, contains('"$name"'));
    });

    test('carries the same five methods on all three sides', () {
      // Both sides answer all of them even though only one side *does*
      // anything with three of them. That is the shape of the port: the
      // asymmetry is in the answers, not in which questions can be asked, so
      // no caller in Dart has to know which phone it is talking to.
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
      // The map is untyped on both sides, so a renamed key arrives as its
      // default — which here is a deadline at the epoch, and a silence lifted
      // a minute after it began.
      expect(androidPlugin, contains('"${ChannelQuietMode.untilArgument}"'));
    });

    test('every access the platforms report is one Dart understands', () {
      // The answer crosses as a string, and an answer Dart does not recognise
      // reads as "this phone cannot" — safe, and silently wrong. These are the
      // three the two native sides actually send.
      for (final access in ['granted', 'denied', 'unavailable']) {
        expect(androidPlugin, contains('"$access"'));
      }
      expect(iosPlugin, contains('"byAutomation"'));
    });

    test('is reached through exactly one implementation', () {
      // The other half of "one shared port": an override point that exists,
      // and one of it. A second implementation chosen in Dart would satisfy
      // every platform-branch check and break the same rule.
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
      // Without this the rule cannot be registered at all, and
      // `isNotificationPolicyAccessGranted` is false forever — a switch the
      // user can turn on that can never do anything.
      expect(manifest,
          contains('android.permission.ACCESS_NOTIFICATION_POLICY"'));
    });

    test('checks that access before using it, and can ask for it', () {
      expect(androidRule, contains('isNotificationPolicyAccessGranted'));
      expect(androidRule,
          contains('Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS'));
    });

    test('owns a zen rule rather than touching the global filter', () {
      // From Android 15 an app cannot change the device's interruption filter:
      // `setInterruptionFilter` is silently redirected into an implicit rule.
      // An app that called it would appear to work and would leave the user
      // with a rule they never saw it create.
      expect(androidRule, contains('addAutomaticZenRule'));
      expect(androidRule, contains('setAutomaticZenRuleState'));
      // The rule's own filter is set on the rule, which is fine and necessary.
      // What is forbidden is setting it on the notification manager — the
      // device's filter — which is the call the platform quietly redirects.
      expect(
        RegExp(r'\bnotifications\s*\.\s*setInterruptionFilter')
            .hasMatch(androidRule),
        isFalse,
        reason: 'The device\'s interruption filter is not this app\'s to set. '
            'Everything happens through the rule it owns.',
      );
    });

    test('lets its own end-of-session notice through its own silence', () {
      // The pair that makes the ticket's fifth criterion true, and it is a
      // pair: the rule allows the reminder category, and ticket 06's
      // completion notification is posted in it. Either half alone is a phone
      // that goes quiet for a session and then never says it is over.
      expect(androidRule, contains('allowReminders(true)'));
      // Total silence has no policy to negotiate: it would swallow the notice
      // along with everything else.
      expect(androidRule, contains('INTERRUPTION_FILTER_PRIORITY'));
      // Read from the code rather than the file: the comments discuss total
      // silence at length, which is most of what there is to say about why the
      // rule does not use it.
      expect(_code(androidRule), isNot(contains('INTERRUPTION_FILTER_NONE')));
      expect(
        File('lib/src/notifications/local_session_notifications.dart')
            .readAsStringSync(),
        contains('AndroidNotificationCategory.reminder'),
      );
    });

    test('holds a deadline nothing of this app has to be alive to keep', () {
      // The ticket's fourth criterion, and the only half of it that survives
      // the process being killed without warning: an alarm set when the
      // session starts, and a receiver that switches the rule off when it
      // fires. Everything else about ending quiet mode needs a live app.
      expect(androidRule, contains('AlarmManager'));
      expect(androidRule, contains('QuietModeReceiver'));
      expect(manifest, contains('android:name=".QuietModeReceiver"'));
      expect(
        File('android/app/src/main/kotlin/com/pomodorogarden/pomodoro_garden/'
                'QuietModeReceiver.kt')
            .readAsStringSync(),
        contains('QuietModeRule(context.applicationContext).end()'),
      );
    });

    test('registers the plugin with the engine', () {
      // A plugin nothing constructs answers nothing, and the failure looks
      // exactly like a platform that cannot do quiet mode.
      expect(
        File('android/app/src/main/kotlin/com/pomodorogarden/pomodoro_garden/'
                'MainActivity.kt')
            .readAsStringSync(),
        contains('QuietModePlugin('),
      );
    });
  });

  group('iOS', () {
    test('exposes an App Intent that opens the app to run', () {
      // The session is the app's to start — anchored, written down, and joined
      // by a plant — so the intent brings the app forward rather than trying
      // to do any of that from a Shortcuts process.
      expect(iosIntent, contains(': AppIntent'));
      expect(iosIntent, contains('openAppWhenRun'));
      expect(iosIntent, contains('QuietModePlugin.requestSession()'));
    });

    test('puts the intent where the user will find it', () {
      // An `AppIntent` that no `AppShortcutsProvider` mentions is in Shortcuts
      // but not in Siri, and is a step harder to find in the app's action
      // list.
      expect(iosIntent, contains('AppShortcutsProvider'));
      expect(iosIntent, contains(r'\(.applicationName)'));
    });

    test('calls the intent what the app tells the user to look for', () {
      // The recipe in settings sends the user hunting for an action by name.
      // If the two ever disagree, the instructions are wrong and there is
      // nothing on either side to say so.
      const title = 'Start a focus session';

      expect(iosIntent, contains('title: LocalizedStringResource = "$title"'));
      expect(
        File('lib/src/features/settings/settings_screen.dart')
            .readAsStringSync(),
        contains('"$title"'),
      );
    });

    test('builds both new files into the app target', () {
      // Swift files existing on disk is not the same as their being compiled.
      // An App Intent left out of the target does not appear in Shortcuts at
      // all, which is a feature that is simply missing with nothing to see.
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

/// [source] with its comment lines taken out.
///
/// Kotlin and Swift comments in this app discuss the platforms constantly —
/// that is most of what the comments this ticket added are about — so an
/// assertion that some API is *not* used has to be made against the code.
String _code(String source) => source
    .split('\n')
    .where((line) {
      final trimmed = line.trimLeft();
      return !trimmed.startsWith('//') &&
          !trimmed.startsWith('*') &&
          !trimmed.startsWith('/*');
    })
    .join('\n');
