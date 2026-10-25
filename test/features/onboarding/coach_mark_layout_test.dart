import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pomodoro_garden/src/design/typography.dart';
import 'package:pomodoro_garden/src/features/onboarding/coach_marks.dart';
import 'package:pomodoro_garden/src/features/onboarding/onboarding_steps.dart';

import '../../support/app_harness.dart';

/// Where the first coach mark's card goes, on every shape of iPhone the app
/// runs on: the shortest, a notch, a Dynamic Island, the largest.
///
/// A file of its own because it loads the real fonts. Whether the card fits
/// above the tab bar with PAUSE still over it is a question about how many
/// lines its copy wraps to, and the stand-in font widget tests use otherwise
/// sets every glyph a full em wide — it would fail the shortest phone for text
/// the phone never shows.
void main() {
  late FixedClock clock;

  setUpAll(() async {
    final loader = FontLoader(GardenTypography.fontFamily);
    for (final path in const [
      'assets/fonts/Inter-Regular.ttf',
      'assets/fonts/Inter-SemiBold.ttf',
      'assets/fonts/Inter-Bold.ttf',
    ]) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(bytes.buffer.asByteData()));
    }
    await loader.load();
  });

  setUp(() => clock = FixedClock(testInstant));

  Future<void> tapThrough(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await settle(tester);
  }

  for (final (phone, size, top, bottom) in const [
    ('iPhone SE', Size(375, 667), 20.0, 0.0),
    ('a notched iPhone', Size(390, 844), 47.0, 34.0),
    ('an iPhone Pro', Size(402, 874), 62.0, 34.0),
    ('an iPhone Pro Max', Size(440, 956), 62.0, 34.0),
  ]) {
    testWidgets('the ring and its card share the screen on $phone',
        (tester) async {
      tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
      addTearDown(tester.view.resetPadding);
      await pumpApp(tester, clock: clock, firstLaunch: true, surface: size);
      await tapThrough(tester, OnboardingKeys.next);
      await tapThrough(tester, OnboardingKeys.next);
      await tapThrough(tester, OnboardingKeys.start);

      final card = tester.getRect(find.ancestor(
        of: find.text('Your first session is growing'),
        matching: find.byType(Card),
      ));
      final ring = tester.getRect(find.byKey(CoachMarkTargets.timer));
      final pause = tester.getRect(find.ancestor(
        of: find.text('Pause'),
        matching: find.byType(FilledButton),
      ));
      final tabs = tester.getRect(find.byType(NavigationBar));

      expect(card.bottom, lessThanOrEqualTo(tabs.top),
          reason: 'above the tab bar, like the other two');
      expect(ring.top, greaterThanOrEqualTo(top),
          reason: 'clear of the status bar and the Dynamic Island');
      expect(ring.bottom, lessThan(card.top),
          reason: 'the whole ring is above the card, none of it under it');
      expect(pause.bottom, lessThan(card.top),
          reason: 'and the session can still be paused');
      expect(tester.getRect(find.byKey(CoachMarkLayer.highlightKey)),
          rectMoreOrLessEquals(ring.inflate(4)),
          reason: 'the outline is drawn where the ring is, not where it was');

      // Put away, the pot has its room back — on the phones where the card
      // took any. On the tallest there is room for both, and the pot was
      // never made smaller.
      await tester.tap(find.text('Got it'));
      await settle(tester);
      final after = tester.getRect(find.byKey(CoachMarkTargets.timer)).height;
      expect(after, greaterThanOrEqualTo(ring.height));
      if (phone == 'iPhone SE') expect(after, greaterThan(ring.height));
    });
  }
}
