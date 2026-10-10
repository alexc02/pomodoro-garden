# 24 — Performance and battery hardening

> **PRD v2.2:** performance targets are measured but **do not block v1.0** (§4.4). The reference devices are the owner's iPhone, the iOS Simulator and the Android emulator. The remaining readings happen in ticket **39**; the loop-seam criterion is settled by ticket **37**.

**What to build:** The app meets every number in PRD §4.4 on real hardware, including an older mid-range Android device — not just on a current-generation flagship. A garden that stutters or a timer that eats battery undoes the calm the whole product is selling.

**Blocked by:** 07, 08, 10, 23

**Status:** **not done, and cannot be closed here — seven of the nine criteria need hardware this machine does not have, and three of those additionally need assets ticket 23 has not delivered.** Two are fully closed. The other seven are taken as far as anything short of a phone can take them: each has a measurement that is not the criterion but would catch the regression that breaks it, and a written method so the real reading is an afternoon rather than a design exercise. A criterion is ticked below only when nothing further is owed it. The full scoreboard is `docs/performance-record.md`. What *was* built is the one piece of shipping code this ticket inherited — REQ-023's sway in the garden, which ticket 07 deferred here for a number — plus the measurement apparatus for all nine, and the Android binary-size reading, which is genuinely taken.

**Revisited after ticket 23 (2026-08-29), and it does not close.** Ticket 23 was worked to a
conclusion and its conclusion is that **the commissioned art does not exist and cannot be
produced here**, so the three criteria that were waiting on a late delivery are now waiting
on one that has not arrived at all. Nothing else moved: there is still no phone, no
emulator, no macOS and no store. What that pass *did* produce for this ticket is a re-taken
binary-size reading and one correction to the scoreboard — see **What the ticket 23 pass
changed here**. Suite totals are now **957 app and 384 domain** (was 924 and 384 when this
ticket was written; the difference is ticket 23's twelve).

- [ ] A 200-plant garden with real art, seasonal particles and sway animation holds 60fps while panning and zooming, on a mid-range Android device and an older supported iPhone — **the sway is built and measured** (0.15–0.17 ms per frame with everything on, against 0.07–0.09 still; ADR 0020), but the art is ticket 23's and a frame time needs a GPU
- [ ] Cold launch to a visible garden is under 1.5 seconds — the app's own share is measured and, more usefully, is **flat in the size of the garden** (288–316 ms empty, 327–353 ms with 200 plants, one atlas bake either way). The other half of that 1.5 s is process start, engine load and the first rasterised frame, and none of it happens without a device
- [ ] Battery drain is under 3% per 25-minute session with the screen off, ambient sound playing and the live surface active — measured, with the method documented — **method documented, nothing measured**; there is no phone here to drain
- [ ] Timer accuracy within ±1 second across a real 120-minute backgrounded session on both platforms — **exact, not merely within a second**, across a simulated two hours suspended and a two hours killed, asserted off the countdown the user reads. Unticked only because the criterion says *a real session on both platforms*: what is still owed is that each OS delivers the alarm when it said it would
- [ ] Ambient loop seams remain inaudible with the final audio assets — the seam is measured three ways against every bundled file and passes; **the final assets do not exist**, and no test can hear repetition
- [ ] Release binary is under 50 MB on both stores — **Android is 29.3 MB and comfortably inside**, re-taken from a clean build on 2026-08-29 and byte-identical to the incremental one; iOS cannot be built without macOS. Both will move when ticket 23's art lands, and the art set is now weighed against a 16 MB budget on every run of the suite
- [x] Memory is stable across a long session with a large garden — no growth over time from animation or sprite handling — **zero `dart:ui` handles leaked** across every case constructible here, including two readings a thousand animated frames apart
- [x] Profiling results are recorded so regressions are detectable later — `docs/performance-record.md`, `scripts/profile.sh`, and budgets asserted inside the tests so a regression fails CI without anybody reading a document
- [ ] Crash-free rate verified above the §11 target across a soak test on both platforms — a hundred sessions and three animated minutes of a full garden, nothing thrown; **§11's 0.5% is a field metric** and needs two stores

## What the ticket 23 pass changed here

Ticket 24 ends by naming a job for ticket 23: *re-run `./scripts/profile.sh --size` with the
real assets and update the size section, because its own seventh criterion is the same
measurement.* There are no real assets, so half of that was possible. The run was taken
anyway, and it found something.

**The binary is 29.3 MB, not 28.8 MB, and the 0.45 MB is explained.** A clean rebuild came
back **byte-identical** to the incremental one — 29,252,562 bytes for arm64 — so the build
is reproducible and the number genuinely moved. It moved because **this ticket's reading
predates `assets/art/` existing**: the stand-in set was written by `tool/generate_art.dart`
afterwards, and it is 79 files contributing 356,790 compressed bytes, plus about 96 KB of
asset manifest and zip alignment. §6 as this ticket wrote it — *every number above is with
placeholder art, which is drawn from code and weighs nothing* — was true when written and
stopped being true the moment the stand-ins landed as files. Corrected in
`docs/performance-record.md`, with the arithmetic.

It is a small number and the criterion is not in danger at 29.3 against 50. It is worth
writing down because **this is the record doing the job it was built for**: a figure moved,
the scoreboard said what it should have been, and the cause was found rather than assumed.

**The sixth criterion is now partly enforced rather than wholly owed.** Ticket 23 added
`test/garden/art_delivery_test.dart`, which weighs the delivered art set on every run of the
suite and fails above **16 MB** — the 20.7 MB of headroom this table measures, less a
margin. An art delivery that would blow §4.4's 50 MB now fails in the suite, where the fix
is compression, rather than in a store's upload dialog. The binary reading after the swap
still needs the swap.

**Everything else re-ran green**, and the benchmarks reproduced — but two of them came back
marginally *above* the top of their recorded ranges, which is worth writing down rather than
rounding away:

| | Recorded | This run |
|---|---|---|
| 200 plants, panning | 0.07 – 0.09 ms | 0.078 ms |
| 200 plants, panning and swaying | 0.15 – 0.17 ms | **0.177 ms** |
| 200 plants, through the widget tree | 2.5 – 3.1 ms | 3.07 ms |
| Launch, empty garden | 288 – 316 ms | 299 ms |
| Launch, 200 plants | 327 – 353 ms | **388 ms** |

Both are single readings on a debug build on a loaded box, against ranges taken over three
runs, and both tests' own asserted budgets still pass — so this is noise, not a regression,
and the ranges are not being widened on the strength of one sample. It is recorded because
the whole point of the file is that somebody notices when a number moves: if the next run
also lands high, the ranges want re-taking on a quiet machine rather than quietly relaxing.

## Why this ticket does not close

Two reasons, and neither is a decision anybody made badly.

**It is blocked by ticket 23, which has now been worked and did not close either.** Three
criteria name things that do not exist: *real art* in the first, *the final audio assets*
in the fifth, and a binary size in the sixth that is measured with stand-in art. Ticket 23
is the one ticket allowed to slip when art is late — that is the whole point of the
placeholder strategy — and this ticket inherits the slip. What changed is the character of
the wait rather than its length: ticket 23's own status is now **the art does not exist and
cannot be produced here**, so these three are waiting on a commission, not on a courier.

**The other six are device measurements and there is no device.** No iOS hardware, no
Android hardware, no emulator (`/dev/kvm` is absent, and an iOS simulator needs macOS).
This is the same constraint every ticket from 06 onwards has recorded, but it is the first
ticket where the constraint is not a gap *around* the work — it is the work. A frame time
needs a GPU and a vsync; a battery percentage needs a battery.

So the ticket was worked as: **build the one thing it owns that is code, and make every
criterion as close to closed as it can be got without hardware** — which for most of them
means a measurement that is not the criterion but would catch the regression that breaks
it, and a written method so that taking the real reading is an afternoon rather than a
design exercise.

## What was built

| Where | What |
|---|---|
| `lib/src/garden/plant_sway.dart` | `PlantSway` — REQ-023's motion as arithmetic, so the timer screen and the garden cannot disagree about it |
| `lib/src/garden/garden_painter.dart` | The lean, as the rotation field the batch was already carrying and passing zero |
| `lib/src/features/garden/garden_view.dart` | One controller for two hundred plants, handed to the painter as its `repaint`; stopped outright under Reduce Motion |
| `lib/src/garden/growing_plant.dart` | Now leans through `PlantSway` rather than repeating its arithmetic |
| `test/garden/garden_sway_test.dart` | 12 tests: that it leans, that the ground and the furniture do not, that it never passes two degrees, that it does not pulse, and that the batch is the same size as a still one |
| `test/garden/garden_memory_test.dart` | 7 tests counting `dart:ui` handles — the criterion about growth, measured as a derivative |
| `test/performance/timer_accuracy_test.dart` | 4 tests: two hours suspended, two hours killed, and the countdown read off the ring |
| `test/performance/cold_launch_test.dart` | 5 tests: launch is flat in garden size, and the first garden frame is the real garden |
| `test/performance/soak_test.dart` | 2 tests: a hundred varied sessions, and three animated minutes of a full garden |
| `test/garden/garden_performance_test.dart` | The swaying row ticket 07 could not fill in, and the structural claim under it |
| `scripts/profile.sh` | The repeatable run: the same benchmarks in the same order, `--size` for a release build |
| `docs/performance-record.md` | The scoreboard — every criterion, what it came to, and what is still owed |
| `docs/adr/0020-the-garden-sways-in-the-batch.md` | The decision ticket 07 asked this one to make, and what it costs |
| `docs/garden-performance-baseline.md` | Its open question, answered; its device table, superseded |
| `docs/battery-baseline.md` | Three things that changed under its method since it was written |
| `test/support/app_harness.dart` | `settle`'s doc widened from a warning about one screen to a rule about all of them |
| `test/settings/settings_providers_test.dart` | The one test that had not got that memo |
| `CONTEXT.md` | *sway*, *baked*, *budget*, *still owed*, under a new *Holding the numbers* heading |

## The decision this ticket was created to make

Ticket 07 built the garden and deliberately left REQ-023's sway out of it, writing down
exactly why: *a swaying garden is a continuously animating screen, and putting one in
before the frame budget has ever been measured on a device is choosing the expensive
default blind. Ticket 24 should decide it with a number in hand.*

**The number is 0.09 ms.** That is what swaying adds to the painter's own per-frame work
for two hundred plants — from 0.07–0.09 ms to 0.15–0.17 ms, or about one per cent of a
16.7 ms frame. It ships.

It was affordable for the reason ticket 07 predicted: `drawAtlas` takes an `RSTransform`
per quad, an `RSTransform` carries a rotation, and the garden had been passing zero. So a
swaying garden is the same four hundred quads in the same one draw call, plus two hundred
`sin` calls. No extra quad, no extra draw, no widget — and `garden_sway_test.dart` asserts
the two batches are the same length so it stays that way.

Two things about it were not obvious before building it:

**The painter listens to the controller; it is not rebuilt by it.** `CustomPainter` takes
a `repaint` listenable, so a frame of the sway is a repaint and nothing else — no build,
no layout, no widget touched. Had the sway been a `double` on the painter, every frame
would need a new painter, which needs a `setState`, which rebuilds and re-lays-out the
whole garden tab sixty times a second to move some pixels. On a screen that now animates
continuously, that is the difference between the two designs and it is a battery
difference.

**Reduce Motion stops the controller rather than being ignored by it.** A repeating
controller nobody reads still asks for a frame every vsync — a continuous animation
running to produce a still picture, which is the worst of both halves. Stopping it and
returning it to zero is also what leaves every plant *upright* rather than frozen at
whatever angle the sine had reached, which is the picture the setting is actually asking
for.

## What the sway cost, beyond the frame

**The garden is now a screen that never stops animating.** `TickerMode` stops it behind
another tab, a backgrounded app gets no frames at all, and Reduce Motion stops it
outright — so §4.4's *drain during a session* is untouched, and it was already true in
three seasons out of four because ticket 14's weather animates. What changes is summer,
and the shape of the claim: there is no still state on the garden tab any more.

**§4.4 does not budget the foreground at all**, and now there is something to budget. That
is recorded as a gap rather than papered over.

**`pumpAndSettle` is now unusable on a launched app.** The app opens on the garden, and a
repeating ticker never settles. The harness has had `settle` for this reason since the
timer screen started swaying; this ticket widened its documentation from *a screen showing
a mature plant* to *any launched screen*, and fixed the one test that still called
`pumpAndSettle` — which is how the constraint was found.

## Two things worth knowing about how the measurements are built

**The memory criterion is a derivative and is measured as one.** "No growth over time"
cannot be checked with a single count: how many `dart:ui` handles a running app holds at
any instant is a property of how many layers are on screen — about eighteen pictures, none
of them the garden's doing. So the long-visit test takes two readings a thousand animated
frames apart and asserts they are equal. The counts themselves come from
`Image.onCreate`/`onDispose`, which makes a leak an exact number rather than a shape on a
graph, and the hooks are process-global so they are put back even when an expectation
fails.

**The launch criterion is a shape, not a millisecond count.** A budget in milliseconds
measured on a debug build on whatever box CI gives us is worth very little. What is worth
a great deal is that launch does not scale with the garden — a user four hundred sessions
in must launch like one on their second day — and that *is* checkable here. A launch that
walked the plants, built a widget per plot or baked a cell per plant would pass a
millisecond budget on an empty garden and fail the user who has actually been using the
app.

## Verification gaps

- **No frame was ever rendered.** Every garden number in this ticket is CPU-side work
  measured under `flutter test`, which has no GPU and no vsync. The design deliberately
  moves work to the raster thread, and the raster thread is exactly what cannot be seen
  here. `docs/garden-performance-baseline.md` has the DevTools procedure and the empty
  table.
- **No battery was ever drained.** The method in `docs/battery-baseline.md` is unchanged
  and unexecuted. This ticket added what has changed underneath it since ticket 06 wrote
  it, including that there is now a foreground drain worth taking while the phone is out.
- **The reference Android device is still not named.** PRD §12's open question 8, flagged
  by ticket 07 as the thing that must be settled before a frame-budget reading can be
  interpreted. This ticket did not settle it either: it is a product decision about which
  phones are supported, not a measurement, and every device-side criterion is waiting on
  it.
- **iOS could not be built at all.** No macOS, so no archive, no thinned size, and no
  MetricKit. The 20.7 MB of Android headroom is a reasonable prior for iOS being fine and
  it is a prior rather than a reading.
- **The crash criterion is not the crash criterion.** §11's 0.5 % is a field metric — its
  own PRD row says Xcode Organizer and Play vitals — and no amount of local soaking
  produces it. The soak asserts something sharper and narrower: that the hundredth session
  behaves like the first.
- **Nobody has heard the loop.** The seam is measured as a click, a gap and a level, and
  all three pass. Whether the *material* repeats noticeably is a judgement about a
  recording that has not been made.
- **The soak costs three minutes of suite time.** `flutter test` went from about four
  minutes to seven, almost all of it the hundred-session run and the three-minute animated
  garden. That is a real price for a criterion that is about behaviour over time, and it
  is the sort of thing worth moving to a nightly job if the loop starts to hurt.
- **Hit-testing ignores the sway.** A tap is tested against where a plant stands, not where
  it is leaning — about three pixels at the top of the tallest sprite. The alternative is a
  hit-test that depends on the instant the finger landed, which is worse. Recorded rather
  than fixed, in ADR 0020.
- **The ambient bed's Android gap is still open.** `docs/ambience.md` raised it for this
  ticket: nothing keeps the process alive for the bed if the user turns REQ-033's
  foreground service off. Both available fixes couple two features the user is
  deliberately offered separately, and neither is a performance decision. Left where it
  was, and named again in `docs/performance-record.md`.

## What ticket 23 has to do before this can be closed

**This was attempted on 2026-08-29 and got as far as it could without art.** The size run
was re-taken, the scoreboard corrected, and the art budget turned into a failing test — see
*What the ticket 23 pass changed here*. What is still owed is the same measurement **with
real assets in it**, which needs the commission.

When a device exists, the remaining five criteria need, in order: the frame reading with a
seeded 200-plant garden, the battery run with everything switched on, the cold-launch
trace, a listener on the finished audio, and a released build in front of both stores'
vitals dashboards. None of the five has moved, and none of them can move here.
