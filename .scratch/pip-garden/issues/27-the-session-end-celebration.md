# 27 — The plant blooms when the session ends

**What to build:** §5.3's fourth animation — *session end celebration · 2s · spring + ease · plant blooms with particle petals/spores*. It is the only one of §5.3's six that was never built, and unlike ticket 23's art and ticket 25's recordings, nothing outside this repository is needed to finish it.

**Blocked by:** 04, 13 — both done.

**Status:** done.

- [x] A completing session blooms: the plant's arrival at its final stage is celebrated for about 2 seconds, with petals or spores, on a spring-and-ease curve (§5.3)
- [x] It plays once per completed session, at the instant the session completes, and never on a cancelled or voided one — those earn nothing and say nothing
- [x] It does not play for a session **found** completed rather than watched — the same rule `SessionAnnouncer` already applies to the chime, and for the same reason
- [x] It settles into the mature plant's ordinary sway rather than ending and handing over — REQ-023's sway is continuous and is already running by then
- [x] `MilestoneKeeper` still raises its card after everything has stopped moving — see *The 1.5 seconds this invalidates* below
- [x] A phone asking for reduced motion does not get it, and does not get a static substitute that looks broken
- [x] The garden's own frame budget is untouched: this is the timer screen's plant, not two hundred of them — see *Where it does not belong* below

## Where the moment is now

A session completing changes the plant's colour to `garden.bloom` and swaps the controls for the break offer (`lib/src/features/timer/timer_screen.dart:114,144`). The chime plays, the haptic fires, and the growth spring runs one last time as the plant reaches its fifth stage. What is missing is everything §5.3 calls the celebration: the bloom, the petals, and the two seconds.

`GrowingPlant`'s own doc comment is honest about the omission — it scopes itself to "§5.3's three plant animations, and nothing else" (`lib/src/garden/growing_plant.dart:11`). This ticket makes it four, and `growing_plant.dart` is where it goes: it already owns the drop, the growth spring and the sway, it already takes the `PlantGrowth` off the session snapshot, and it is already the one widget that knows a plant is animating rather than merely drawn.

`plant_painter.dart:89` is the model to copy for the particles. The seed's landing burst is "six specks thrown out from" the point of impact, drawn by the painter rather than by widgets, with no per-particle state to advance — which is the same shape a spray of petals wants, and the same reason it is cheap.

## The 1.5 seconds this invalidates

This is the one piece of existing code the ticket genuinely breaks, and it should be read before anything is written.

`MilestoneKeeper._afterTheSession` is 1500 ms, and its doc comment says exactly why:

> §5.3's growth spring runs for about 1.2 seconds and is the last thing to move when a session completes. This is a little past it, so the plant has stopped springing before anything slides over it.

After this ticket the growth spring is **no longer the last thing to move** — a 2-second celebration is — and 1500 ms becomes a number that slides a sheet up through the middle of the bloom. That is precisely the "two events out of one moment" the keeper was built to prevent.

Fix the constant, and fix its comment with it. The comment is the thing that will otherwise be wrong in a way nobody notices for a year: it names the growth spring by name, so leaving it while changing the number would leave a false explanation attached to a correct value. The keeper's hundredth-session behaviour is covered by `test/performance/soak_test.dart`, which walks past every milestone REQ-021 awards, so a regression here has somewhere to show up.

## Where it does not belong

**Not in the garden.** The garden is one `drawAtlas` batch of up to two hundred quads (ADR 0020), and the sway is in it because it cost 0.08 ms a frame and nothing else could carry it. A particle system per plant is a different proposition entirely, and there is no requirement asking for one — §5.3's trigger is *session completes*, which happens to one plant on one screen while the user is looking at it. The plant the user watched grow blooms on the timer screen; the garden shows it mature the next time they visit, exactly as it does today.

**Not a second celebration.** REQ-021's milestone card is the app's other celebration and it is deliberately quiet, deliberately late, and deliberately not shown over a countdown (`CONTEXT.md`, *Celebration*). This one is neither its replacement nor its rehearsal — the two happen in sequence at the tenth session, and the acceptance criterion above is that they read as two things rather than one pile-up.

## Testing it

`pumpAndSettle` cannot be used anywhere near a completed session, and this ticket makes that sharper rather than introducing it: a mature plant is already swaying forever, which is why `test/support/app_harness.dart` has `settle(tester)` and why ticket 04 wrote that rule down. Use it.

The thing worth asserting beyond "it does not throw" is the ordering — that nothing else arrives on screen while the bloom is running — because that is the requirement with a real failure mode and the one the milestone constant above can silently break.

## What was built

**`GrowingPlant` takes a `completed` flag, and blooms on its turn from false to true under a plant that was already on screen.** That edge is the whole of "once, at the instant": a completed session that sits on screen rebuilds the widget for as long as it is there, and none of those rebuilds is an edge. A plant handed over already complete — the timer screen built after the fact — never blooms, and neither does a session that changes plant at the same moment. A cancelled or voided session clears the soil, which resets the bloom and leaves nothing to bloom.

**Spring and ease, two seconds (`GrowingPlant.bloomDuration`).** The ease is the petals: `PlantPainter._paintBloom` throws twelve petals from the crown in every direction, eased out, falling gently and fading, drawn as a pure function of `bloom` exactly as the landing burst is. The spring is the plant. A completion that also reaches the last stage is already springing from the stage transition and is left alone. A plant that matured earlier, which REQ-009's half-rate growth can do, is kicked outward by `GrowingPlant.bloomKick` on top of whatever velocity the spring already has. A kick rather than a re-run from `growthFrom`, so the same sprite doesn't visibly shrink before it pops.

**Found versus watched is the timer screen's call, and it uses the announcer's rule.** `SessionAnnouncer`'s 2-second freshness check is now `SessionAnnouncer.watched(dueAt:, now:)`. The chime and the timer screen's `_watchedComplete` both call it, so a session that ran out with the app away is found on the way back in and neither chimes nor blooms. The two are one rule, read in one place.

**The sway is untouched.** It starts when the plant matures, at the completion or before it, so it is already running under the petals and carries on once they have faded. Nothing hands over.

**Reduced motion gets no bloom at all.** `didChangeDependencies` reads `MediaQuery.disableAnimationsOf`. With it on, a completion does not start the bloom, and a bloom already in flight is reset to nothing rather than frozen. The plant is simply mature.

**`MilestoneKeeper.afterTheSession` is now `GrowingPlant.bloomDuration + 300 ms` (2.3 s), and its comment names the bloom.** It is derived rather than written as a number, so a longer bloom moves the card with it. It is public so tests wait on it: `test/support/celebrations.dart` gained `waitForCelebration`, which replaces the "two settles" several milestone tests and `dismissCelebrations` used to count on.

**The garden is untouched.** `GardenPainter` and its `drawAtlas` batch are unchanged. The garden shows the plant mature the next time it is visited.

**`CONTEXT.md` gains *Bloom*.** The glossary reserves *Celebration* for the milestone sheet and lists *confetti* under it, so §5.3's "session end celebration" needed a word of its own that does not collide. The code and tests use *bloom* throughout, and cite the PRD's phrase only where they quote it.

## Tests

- `test/garden/growing_plant_test.dart`, *the bloom at the end of a session*:
  - petals go out and do not come back
  - the bloom is over at two seconds
  - an already-mature plant still springs
  - it plays once
  - a cancelled session does not bloom, and neither does a session found complete
  - the bloom settles into the sway
  - under reduced motion there are no petals, and a bloom in flight is ended
- `test/features/timer/session_end_bloom_test.dart`, through the real app: a watched completion blooms; one that completed with the app backgrounded does not; a cancelled session does not.
- `test/garden/milestone_test.dart`, *waits for the bloom to finish before it rises*: the ordering assertion the ticket asks for, checked on every frame through the tenth session's bloom. With the old 1500 ms it fails, because the card rises while the petals are still in the air.
- Fixed in the pre-written test *springs as well…*: it asserted `bloom == 1` after 90 frames, which is 1.44 s, inside a 2-second bloom. It now asserts the petals are still flying.
- `flutter analyze --fatal-infos` is clean. The full app suite (958) passes, including `test/performance/soak_test.dart`, which walks past every milestone. The domain suite (382) passes.

## Review

The two-axis review found no missing requirements. Acted on:
- glossary breaches: "celebration" used for the bloom, and "finished" used for a session
- the bloom helper, which was duplicated between two test files and now lives in `test/support/plant_pose.dart`
- the keeper constant, which was hard-coded rather than derived from the bloom
- petals that could be drawn above the plant's box and onto the ring, since the painter does not clip
- a kick that could reverse a spring still in flight

Left as they are, on purpose:
- **`watched` stays on `SessionAnnouncer`.** The reviewer suggested moving it beside the session. The rule is the announcer's, and the bloom is a second reader of it, not its owner.
- **A session that completes while the cancel dialog is open blooms behind the dialog's barrier.** That is the instant it completed, and the dialog is the user's own doing.
- **A session that completes while the timer tab is hidden blooms on the hidden tab.** Its ticker keeps time, so returning within two seconds shows the tail of the bloom and returning later shows the mature plant.

## Verification gap

Nothing here has been seen on a device. There is no iOS simulator or Android emulator on this machine, so the bloom has only been verified as numbers off the painter, never as pixels. Whether twelve petals at these sizes and colours read as a bloom rather than as confetti on a real phone, and whether the bloom holds 60 fps on the PRD §12 #8 reference device, is for the next on-device pass. It is one `CustomPaint` drawing a dozen ovals, so the frame cost is not expected to matter.

Two things predate this ticket, are not changed by it, and are worth noting: the timer screen's drop, growth spring and sway do not follow reduced motion the way the garden's sway does, and so the spring the bloom adds to an already-mature plant does not either. The ticket's criterion is about the bloom, and the bloom's petals do follow it.
