# 16 — Onboarding to first session in under 60 seconds

**What to build:** A new user opens the app for the first time, sees a welcome with a preview of a flourishing garden, picks a session length, and taps start — no account, no sign-up, nothing else in the way. Coach marks then teach the three things worth knowing, layered over the real app rather than in a separate slideshow.

**Blocked by:** 03, 04

**Status:** done

- [x] Exactly three onboarding steps: welcome + garden preview, choose session length, start (REQ-003)
- [x] Measured time from first launch to a session actually running is under 60 seconds at a natural pace, and every step is skippable
- [x] No account, no sign-in, no permission prompt blocks the first session
- [x] The chosen length is written to settings and used for that first session
- [x] After the first session starts, at most three coach marks appear over the live UI — timer, garden, journal — each individually dismissible, never blocking the session
- [x] Onboarding shows once; it does not reappear on relaunch, and there is a documented way to reset it for testing
- [x] The welcome garden preview looks lush and appealing even though the real garden is empty
- [x] The seed-drop animation is visible on the first session so the reward loop is immediately legible (US-005)

## How it was built

**The flow is a layer over the app, not a route.** `OnboardingOverlay` wraps `AppShell` in
an unconditional `Stack` inside every other keeper, so the shell is alive behind the
welcome and the last step is a hand-off rather than a navigation: START writes the setting,
selects the timer tab, starts the session, and the overlay stops drawing. The `Stack` stays
in the tree when onboarding is done, because changing the shape of the tree at that moment
would rebuild the shell and drop the user's seed a second time.

**Three steps, counted by the enum.** `OnboardingStep` — welcome, sessionLength, start —
drives the flow *and* the step indicator, so a fourth screen would be a change to the
vocabulary rather than a widget slipped into a layout. Skip is on all three and leaves the
whole of onboarding, coach marks included.

**Three coach marks, anchored to the real widgets.** `CoachMarkTargets` holds global keys
carried by the session ring and two of the four navigation destinations; a mark outlines
its target and puts a card near it. No barrier and no modal route, so PAUSE still pauses
while a card is up — tested.

**One bit in the settings row.** `GardenSettings.onboardingCompleted`, schema version 13,
written when the flow is left by either route. The migration backfills every existing row
as *done* so an upgrade does not greet a user of three weeks with a welcome screen, and
settings that cannot be read at all now fall back to *done* for the same reason.

**Reset:** Settings → **Onboarding (debug)** → Show onboarding again. Debug builds only;
documented in `README.md`.

Reasoning, including what the under-a-minute test does and does not prove, is in
`docs/adr/0013-onboarding-is-a-layer-over-the-running-app.md`. New vocabulary — onboarding,
step, coach mark, preview garden — is in `CONTEXT.md`.

Tests: `test/features/onboarding/onboarding_test.dart` (22), plus the settings, repository
and migration cases for the new field. `./scripts/check.sh` is green — 615 app tests and
324 in the domain core.
