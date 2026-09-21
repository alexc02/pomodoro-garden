import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_analytics_event_log.dart';
import 'package:pip_garden/src/data/drift_garden_reset.dart';
import 'package:pip_garden/src/features/settings/event_log_screen.dart';
import 'package:pip_garden/src/features/settings/settings_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';

// The debug-only event log viewer, the only place the events can be seen.
void main() {
  late FixedClock clock;
  late AppDatabase database;

  setUp(() {
    clock = FixedClock(testInstant);
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  /// Seeds [events] before launch, oldest first.
  Future<void> alreadyRecorded(List<AnalyticsEvent> events) async {
    final log = DriftAnalyticsEventLog(database);
    for (var index = 0; index < events.length; index++) {
      await log.append(
        events[index],
        at: testInstant.add(Duration(minutes: index)),
      );
    }
  }

  /// Launches and opens the log through settings.
  Future<void> openTheLog(WidgetTester tester) async {
    await pumpApp(tester, clock: clock, database: database);
    await tapTab(tester, AppTab.settings);
    await tester.tap(await scrollToSetting(tester, SettingsKeys.eventLog));
    await settle(tester);
  }

  testWidgets('lists what was recorded, with its parameters', (tester) async {
    await alreadyRecorded([
      SessionStarted.of(const Duration(minutes: 50)),
      const SettingsChanged(
        setting: SettingKey.haptics,
        oldValue: 'on',
        newValue: 'off',
      ),
    ]);

    await openTheLog(tester);

    expect(find.text('session_started'), findsOneWidget);
    expect(find.text('duration_seconds: 3000'), findsOneWidget);
    expect(find.text('is_custom: false'), findsOneWidget);

    expect(find.text('settings_changed'), findsOneWidget);
    expect(find.text('setting_key: haptics'), findsOneWidget);
    expect(find.text('old_value: on'), findsOneWidget);
    expect(find.text('new_value: off'), findsOneWidget);
  });

  testWidgets('shows the newest first', (tester) async {
    await alreadyRecorded([
      SessionStarted.of(const Duration(minutes: 15)),
      SessionStarted.of(const Duration(minutes: 50)),
    ]);

    await openTheLog(tester);

    final durations = tester
        .widgetList<Text>(find.textContaining('duration_seconds:'))
        .map((text) => text.data)
        .toList();

    expect(durations, ['duration_seconds: 3000', 'duration_seconds: 900']);
  });

  testWidgets('says how many it is holding, and that none of it goes anywhere',
      (tester) async {
    await alreadyRecorded([SessionStarted.of(const Duration(minutes: 25))]);

    await openTheLog(tester);

    // Shown under the events.
    expect(find.textContaining('has ever left the device'), findsOneWidget);
    expect(
      find.textContaining(
        RegExp('\\d+ events, of the ${AnalyticsEventLog.maximumEvents}'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an empty log says so rather than showing an empty list',
      (tester) async {
    await openTheLog(tester);

    // A launch always logs `app_opened`, so clear the log under the screen to
    // see it empty.
    await DriftGardenReset(database).clear();
    await tester.tap(find.byIcon(Icons.refresh));
    await settle(tester);

    expect(find.byKey(EventLogKeys.empty), findsOneWidget);
    expect(find.byKey(EventLogKeys.log), findsNothing);
  });

  testWidgets('reading it again picks up what has happened since',
      (tester) async {
    await openTheLog(tester);
    expect(find.text('session_started'), findsNothing);

    await alreadyRecorded([SessionStarted.of(const Duration(minutes: 25))]);
    await tester.tap(find.byIcon(Icons.refresh));
    await settle(tester);

    expect(find.text('session_started'), findsOneWidget);
  });

  testWidgets('is not part of the app the user is handed', (tester) async {
    // Not reachable from the tabs; the settings entry is behind `kDebugMode`.
    await pumpApp(tester, clock: clock, database: database);

    for (final tab in AppTab.values) {
      await tapTab(tester, tab);
      expect(find.byType(EventLogScreen), findsNothing,
          reason: 'the log is not the ${tab.label} tab');
    }
  });
}
