import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:pip_garden/src/design/typography.dart';
import 'package:pip_garden/src/features/onboarding/coach_marks.dart';
import 'package:pip_garden/src/features/onboarding/onboarding_steps.dart';

import '../../support/app_harness.dart';

// First coach mark card placement on each iPhone shape.
//
// Separate file because it loads the real fonts. The stand-in test font
// renders every glyph a full em wide and would wrap the copy more than a real
// phone does.
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
    testWidgets('ring and card fit on $phone', (tester) async {
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
          reason: 'above the tab bar');
      expect(ring.top, greaterThanOrEqualTo(top),
          reason: 'clear of the status bar and the Dynamic Island');
      expect(ring.bottom, lessThan(card.top),
          reason: 'ring is fully above the card');
      expect(pause.bottom, lessThan(card.top),
          reason: 'PAUSE still reachable');
      expect(tester.getRect(find.byKey(CoachMarkLayer.highlightKey)),
          rectMoreOrLessEquals(ring.inflate(4)),
          reason: 'outline follows the ring');

      // Once dismissed, the pot gets its room back (the largest phone never
      // lost any).
      await tester.tap(find.text('Got it'));
      await settle(tester);
      final after = tester.getRect(find.byKey(CoachMarkTargets.timer)).height;
      expect(after, greaterThanOrEqualTo(ring.height));
      if (phone == 'iPhone SE') expect(after, greaterThan(ring.height));
    });
  }
}
