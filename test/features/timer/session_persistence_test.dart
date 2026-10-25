import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/data/drift_session_repository.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../../support/app_harness.dart';

/// The acceptance criterion this file exists for: a completed session is still
/// there after the app is killed and launched again.
///
/// The database is a real file rather than an in-memory one, and it is closed
/// between the two launches. An in-memory database would prove only that the
/// app re-reads its own process; a file that survives a closed connection is
/// what a relaunch actually depends on.
void main() {
  late Directory directory;
  late File file;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('pip_garden_test');
    file = File('${directory.path}/pip_garden.sqlite');
  });

  tearDown(() => directory.deleteSync(recursive: true));

  testWidgets('a completed session survives a kill and a relaunch',
      (tester) async {
    final clock = FixedClock(testInstant);

    // Launch one: run a session to completion.
    final firstLaunch = AppDatabase.inFile(file);
    await pumpApp(tester, clock: clock, database: firstLaunch);
    await startSession(tester);
    await advance(tester, clock, const Duration(minutes: 25));
    await settle(tester);
    expect(find.text('1 session grown'), findsOneWidget);

    // The kill: the app goes away and takes its connection with it.
    await killApp(tester);
    await firstLaunch.close();

    // Launch two: a new database, a new provider scope, the same file.
    final secondLaunch = AppDatabase.inFile(file);
    addTearDown(secondLaunch.close);
    await pumpApp(tester, clock: clock, database: secondLaunch);
    await tapTab(tester, AppTab.timer);

    expect(find.text('1 session grown'), findsOneWidget);
    expect(find.text('Ready to focus'), findsOneWidget,
        reason: 'the relaunched app is not still counting down');

    final stored =
        await DriftSessionRepository(secondLaunch).completedSessions();
    expect(stored, hasLength(1));
    expect(stored.single.startedAt, testInstant);
    expect(stored.single.plannedDuration, const Duration(minutes: 25));
    expect(stored.single.completed, isTrue);
    expect(stored.single.endedAt, testInstant.add(const Duration(minutes: 25)));
  });

  testWidgets('a session that never completed is not counted as one that did',
      (tester) async {
    // REQ-013 gives this session a fate — voided — which is ticket 05's to
    // decide. What ticket 02 owes is that it does not count as completed.
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
