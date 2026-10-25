import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/quiet/quiet_mode.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/quiet_mode_fake.dart';

/// What the settings screen offers about quiet mode, which is the ticket's
/// whole point made visible: **the control appears where the automation is
/// real, and nowhere else.**
///
/// The failure these tests exist to prevent is a switch labelled "Quiet mode"
/// on a phone that cannot deliver one. Nobody would notice it in review — it
/// looks like parity — and the user finds out at the worst possible moment: a
/// call in the middle of the session they thought they had protected.
void main() {
  late FakeQuietMode phone;

  setUp(() => phone = FakeQuietMode());

  Future<void> openSettings(
    WidgetTester tester, {
    GardenSettings? settings,
    AppDatabase? database,
  }) async {
    await pumpApp(
      tester,
      quietMode: phone,
      settings: settings,
      database: database,
    );
    await tapTab(tester, AppTab.settings);
  }

  group('where the phone can silence itself', () {
    setUp(() => phone.reportAccess(QuietModeAccess.granted));

    testWidgets('there is a switch, and it starts off', (tester) async {
      await openSettings(tester);

      final control = await scrollToSetting(tester, SettingsKeys.quietMode);
      expect(tester.widget<SwitchListTile>(control).value, isFalse);
    });

    testWidgets('turning it on silences the next session', (tester) async {
      await openSettings(tester);

      await tester.tap(await scrollToSetting(tester, SettingsKeys.quietMode));
      await settle(tester);

      expect(
        tester
            .widget<SwitchListTile>(find.byKey(SettingsKeys.quietMode))
            .value,
        isTrue,
      );

      await startSession(tester);
      expect(phone.quiet, isTrue);
    });

    testWidgets('nothing is said about permissions that are already given',
        (tester) async {
      await openSettings(
        tester,
        settings: GardenSettings.defaults.withQuietMode(enabled: true),
      );
      await scrollToSetting(tester, SettingsKeys.quietMode);

      expect(find.textContaining("doesn't have permission"), findsNothing);
      // What is said instead is the promise that makes the switch safe to
      // turn on: the app's own news still gets through its own silence.
      expect(find.textContaining("your session's finished"), findsOneWidget);
    });
  });

  group('where the permission has not been given', () {
    setUp(() => phone.reportAccess(QuietModeAccess.denied));

    testWidgets('turning it on explains where the user is being sent, and '
        'then sends them', (tester) async {
      // The ticket's second criterion. There is no runtime dialog for this
      // permission on any platform that has it — the only route is a system
      // settings list of every app on the phone, which is a bewildering place
      // to arrive with no explanation.
      await openSettings(tester);

      await tester.tap(await scrollToSetting(tester, SettingsKeys.quietMode));
      await settle(tester);

      expect(
        find.textContaining('happens in system settings'),
        findsOneWidget,
      );
      expect(phone.accessRequests, isZero);

      await tester.tap(find.text('Open settings'));
      await settle(tester);

      expect(phone.accessRequests, 1);
    });

    testWidgets('walking away from the explanation sends nobody anywhere',
        (tester) async {
      await openSettings(tester);

      await tester.tap(await scrollToSetting(tester, SettingsKeys.quietMode));
      await settle(tester);
      await tester.tap(find.text('Not now'));
      await settle(tester);

      expect(phone.accessRequests, isZero);
    });

    testWidgets('a permission that was taken away shows as off, and says why',
        (tester) async {
      // The ticket's third criterion, on screen. The setting says on and the
      // phone says no, and the control shows the phone's answer: a switch
      // sitting at "on" over a feature that does nothing is the app's word
      // against the device's.
      await openSettings(
        tester,
        settings: GardenSettings.defaults.withQuietMode(enabled: true),
      );

      final control = await scrollToSetting(tester, SettingsKeys.quietMode);

      expect(tester.widget<SwitchListTile>(control).value, isFalse);
      expect(find.textContaining("doesn't have permission"), findsOneWidget);
    });
  });

  group('where no app can silence the phone', () {
    setUp(() => phone.reportAccess(QuietModeAccess.byAutomation));

    testWidgets('there is no switch to claim otherwise', (tester) async {
      await openSettings(tester);

      // Scrolled to the bottom of the screen, so the absence below is an
      // absence rather than a control that has not been built yet.
      await scrollToSetting(tester, SettingsKeys.quietModeRecipe);

      expect(find.byKey(SettingsKeys.quietMode), findsNothing);
    });

    testWidgets('there is a hint, and it leads to the recipe', (tester) async {
      await openSettings(tester);
      await scrollToSetting(tester, SettingsKeys.quietModeHint);

      await tester.tap(find.text('Show me'));
      await settle(tester);

      // The App Intent by the name it has in Shortcuts. If this string ever
      // stops matching `StartFocusSessionIntent.title`, the recipe sends the
      // user looking for an action that does not exist.
      expect(find.textContaining('Start a focus session'), findsOneWidget);
      expect(find.textContaining('Set Focus'), findsOneWidget);
    });

    testWidgets('the hint is shown once ever, not once a launch',
        (tester) async {
      final database = AppDatabase.forTesting();
      addTearDown(database.close);

      await openSettings(tester, database: database);
      await scrollToSetting(tester, SettingsKeys.quietModeHint);
      await tester.tap(find.text('No thanks'));
      await settle(tester);

      expect(find.byKey(SettingsKeys.quietModeHint), findsNothing);

      // The same phone, opened again. A hint that came back would be the
      // nagging this app is sold on not doing.
      await killApp(tester);
      await openSettings(tester, database: database);
      await scrollToSetting(tester, SettingsKeys.quietModeRecipe);

      expect(find.byKey(SettingsKeys.quietModeHint), findsNothing);
      // And the instructions are still there for somebody who put the nudge
      // away and came looking a week later.
      expect(find.byKey(SettingsKeys.quietModeRecipe), findsOneWidget);
    });

    testWidgets('reading the recipe puts the hint away too', (tester) async {
      await openSettings(tester);
      await scrollToSetting(tester, SettingsKeys.quietModeHint);

      await tester.tap(find.text('Show me'));
      await settle(tester);
      await tester.tap(find.text('Close'));
      await settle(tester);

      expect(find.byKey(SettingsKeys.quietModeHint), findsNothing);
    });
  });

  group('where nothing can be done at all', () {
    testWidgets('the section says so and offers nothing', (tester) async {
      // An Android too old to switch its own zen rule on, and every build with
      // nothing registered behind the port. The recipe would be wrong here —
      // it describes a Shortcut this phone has no equivalent of — so what is
      // left is the truth and no controls.
      phone.reportAccess(QuietModeAccess.unavailable);
      await openSettings(tester);

      await scrollToSetting(tester, SettingsKeys.quietModeUnsupported);

      expect(find.byKey(SettingsKeys.quietMode), findsNothing);
      expect(find.byKey(SettingsKeys.quietModeHint), findsNothing);
    });
  });
}
