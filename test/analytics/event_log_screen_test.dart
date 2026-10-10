import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/data/database.dart';
import 'package:pomodoro_garden/src/data/drift_analytics_event_log.dart';
import 'package:pomodoro_garden/src/data/drift_garden_reset.dart';
import 'package:pomodoro_garden/src/features/settings/event_log_screen.dart';
import 'package:pomodoro_garden/src/features/settings/settings_screen.dart';
import 'package:pomodoro_garden/src/shell/tab.dart';

import '../support/app_harness.dart';

/// PRD §7.2's debug-only viewer: the only way the events are ever seen.
///
/// There is no dashboard and no console, so this screen is the whole of what
/// analytics looks like from outside the code — which makes "the events are
/// being recorded with the right parameters" something a person can check by
/// looking.
void main() {
  late FixedClock clock;
  late AppDatabase database;

  setUp(() {
    clock = FixedClock(testInstant);
    database = AppDatabase.forTesting();
    addTearDown(database.close);
  });

  /// Puts [events] in the log before the app is launched over it, oldest first.
  Future<void> alreadyRecorded(List<AnalyticsEvent> events) async {
    final log = DriftAnalyticsEventLog(database);
    for (var index = 0; index < events.length; index++) {
      await log.append(
        events[index],
        at: testInstant.add(Duration(minutes: index)),
      );
    }
  }

  /// Launches, and opens the log the way somebody debugging does: through
  /// settings.
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

    // At the bottom, under the events: the reader came here for those. The cap
    // and the privacy promise are said where somebody reading the log will see
    // them — §7.2 is a claim about this table, and this is the screen that can
    // back it up.
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

    // Emptied under the screen — ticket 22's reset, seen from here — and read
    // again. A launch always records `app_opened`, so this is the only way to
    // look at a log with nothing in it.
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
    // A debug affordance rather than a feature: nothing on the way through the
    // app reaches it, and the section that does is compiled out of release
    // builds by `kDebugMode` at its only call site.
    await pumpApp(tester, clock: clock, database: database);

    for (final tab in AppTab.values) {
      await tapTab(tester, tab);
      expect(find.byType(EventLogScreen), findsNothing,
          reason: 'the log is not the ${tab.label} tab');
    }
  });
}
