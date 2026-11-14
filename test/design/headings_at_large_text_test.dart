import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pip_garden/src/data/database.dart';
import 'package:pip_garden/src/design/headline.dart';
import 'package:pip_garden/src/features/garden/garden_header.dart';
import 'package:pip_garden/src/features/timer/timer_screen.dart';
import 'package:pip_garden/src/shell/tab.dart';

import '../support/app_harness.dart';
import '../support/garden_seed.dart';

// The headings through the real app at the largest accessibility text size:
// nothing truncated, nothing broken inside a word. `headline_test.dart` has
// the rules; this is where they're applied.

const _phone = Size(402, 874);

Future<void> _open(WidgetTester tester, {required double text}) async {
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final database = AppDatabase.forTesting();
  addTearDown(database.close);
  await seedGarden(database, sessions: 9);
  await pumpApp(tester, database: database, surface: _phone);
}

/// Every paragraph under [of] that was cut short.
Iterable<String> _truncated(WidgetTester tester, Finder of) => tester
    .renderObjectList<RenderParagraph>(
      find.descendant(of: of, matching: find.byType(RichText)),
    )
    .where((paragraph) => paragraph.didExceedMaxLines)
    .map((paragraph) => paragraph.text.toPlainText());

void main() {
  for (final text in [1.0, 2.0, 3.1]) {
    testWidgets('the garden header shows all of itself at ${text}x',
        (tester) async {
      await _open(tester, text: text);

      expect(_truncated(tester, find.byType(GardenHeader)), isEmpty);
      expect(find.text(GardenHeader.headline(9)), findsOneWidget);
    });
  }

  testWidgets('at large text the garden headline takes the whole width',
      (tester) async {
    await _open(tester, text: 1);
    final headline = find.descendant(
      of: find.byType(GardenHeader),
      matching: find.byType(Headline),
    );
    final beside = tester.getSize(headline).width;
    final buttonsAt = tester.getTopLeft(find.byType(IconButton).first).dx;
    expect(tester.getRect(headline).right, lessThanOrEqualTo(buttonsAt));

    await killApp(tester);
    await _open(tester, text: 3.1);

    // Under the buttons now, so wider than when it sat beside them.
    expect(tester.getSize(headline).width, greaterThan(beside));
    expect(
      tester.getRect(headline).top,
      greaterThanOrEqualTo(
        tester.getRect(find.byType(IconButton).first).bottom,
      ),
    );
  });

  testWidgets('the timer heading stays whole beside a growing plant',
      (tester) async {
    await _open(tester, text: 3.1);
    await startSession(tester);
    await settle(tester);

    final heading = find.descendant(
      of: find.byType(TimerScreen),
      matching: find.widgetWithText(Headline, 'Focusing'),
    );
    expect(heading, findsOneWidget);
    // One word, one line: as tall as a single line of its own text.
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: heading, matching: find.byType(RichText)),
    );
    final oneLine = TextPainter(
      text: paragraph.text,
      textScaler: paragraph.textScaler,
      textDirection: TextDirection.ltr,
    )..layout();
    addTearDown(oneLine.dispose);
    expect(paragraph.size.height, closeTo(oneLine.height, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the empty-garden caption steps aside at the largest text',
      (tester) async {
    const caption = 'Finish a session and your first plant goes in here.';

    Future<void> launch(double text) async {
      tester.platformDispatcher.textScaleFactorTestValue = text;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final database = AppDatabase.forTesting();
      addTearDown(database.close);
      await pumpApp(tester, database: database, surface: _phone);
    }

    await launch(1);
    expect(find.text(caption), findsOneWidget);

    await killApp(tester);
    await launch(3.1);
    // The timer bar wins the space; the header and the bar don't collide.
    expect(find.text(caption), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no heading on any tab is cut short at the largest text',
      (tester) async {
    await _open(tester, text: 3.1);

    for (final tab in AppTab.values) {
      await tapTab(tester, tab);
      final cut = [
        for (final headline in find.byType(Headline).evaluate())
          ..._truncated(tester, find.byWidget(headline.widget)),
      ];
      expect(cut, isEmpty, reason: '${tab.name} tab');
    }
  });
}
