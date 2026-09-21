import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';

// A completed session must survive a kill and relaunch. Uses a real file,
// closed between launches; in-memory would only prove the same process can
// re-read it.
void main() {
  late Directory directory;
  late File file;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('pip_garden_test');
    file = File('${directory.path}/pip_garden.sqlite');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  testWidgets('completed session survives relaunch', (tester) async {
    final clock = FixedClock(testInstant);

    final firstLaunch = AppDatabase.inFile(file);
    await pumpApp(tester, clock: clock, database: firstLaunch);
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);
    expect(find.text('1 session grown'), findsOneWidget);

    await killApp(tester);
    await firstLaunch.close();

    // New database and provider scope, same file.
    final secondLaunch = AppDatabase.inFile(file);
    addTearDown(secondLaunch.close);
    await pumpApp(tester, clock: clock, database: secondLaunch);
    await tapTab(tester, AppTab.timer);

    expect(find.text('1 session grown'), findsOneWidget);
    expect(find.text('Ready to focus'), findsOneWidget,
        reason: 'not still counting down');

    final stored =
        await DriftSessionRepository(secondLaunch).completedSessions();
    expect(stored, hasLength(1));
    expect(stored.single.startedAt, testInstant);
    expect(stored.single.plannedDuration, const Duration(minutes: 25));
    expect(stored.single.completed, isTrue);
    expect(stored.single.endedAt, testInstant.add(const Duration(minutes: 25)));
  });

  testWidgets('unfinished session is not counted', (tester) async {
    // It ends up voided, but here we only check it isn't counted.
    final clock = FixedClock(testInstant);

    final firstLaunch = AppDatabase.inFile(file);
    await pumpApp(tester, clock: clock, database: firstLaunch);
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 5));
    await killApp(tester);
    await firstLaunch.close();

    final secondLaunch = AppDatabase.inFile(file);
    addTearDown(secondLaunch.close);
    await pumpApp(tester, clock: clock, database: secondLaunch);
    await tapTab(tester, AppTab.timer);

    expect(find.text('No sessions grown yet'), findsOneWidget);
    expect(await DriftSessionRepository(secondLaunch).completedSessions(),
        isEmpty);
  });
}
