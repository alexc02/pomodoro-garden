import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/quiet/quiet_mode.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/quiet_mode_fake.dart';

/// The quiet-mode settings control only appears where the phone can actually
/// silence itself. A switch that does nothing would only be found out in the
/// middle of a session.
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
      // Instead it says the app's own notices still get through.
      expect(find.textContaining("your session's finished"), findsOneWidget);
    });
  });

  group('where the permission has not been given', () {
    setUp(() => phone.reportAccess(QuietModeAccess.denied));

    testWidgets('turning it on explains where the user is being sent, and '
        'then sends them', (tester) async {
      // There's no runtime dialog for this permission, only a system settings
      // list, so explain before sending the user there.
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
      // The setting says on but the phone says no; show the phone's answer.
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

      // Scroll to the bottom so the absence is real, not just off screen.
      await scrollToSetting(tester, SettingsKeys.quietModeRecipe);

      expect(find.byKey(SettingsKeys.quietMode), findsNothing);
    });

    testWidgets('there is a hint, and it leads to the recipe', (tester) async {
      await openSettings(tester);
      await scrollToSetting(tester, SettingsKeys.quietModeHint);

      await tester.tap(find.text('Show me'));
      await settle(tester);

      // Must match `StartFocusSessionIntent.title` in Shortcuts.
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

      // Same phone, reopened: no nagging.
      await killApp(tester);
      await openSettings(tester, database: database);
      await scrollToSetting(tester, SettingsKeys.quietModeRecipe);

      expect(find.byKey(SettingsKeys.quietModeHint), findsNothing);
      // The instructions are still there if they come looking later.
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
      // Old Android without zen rule access, or no implementation behind the
      // port. The Shortcuts recipe doesn't apply, so just say so.
      phone.reportAccess(QuietModeAccess.unavailable);
      await openSettings(tester);

      await scrollToSetting(tester, SettingsKeys.quietModeUnsupported);

      expect(find.byKey(SettingsKeys.quietMode), findsNothing);
      expect(find.byKey(SettingsKeys.quietModeHint), findsNothing);
    });
  });
}
