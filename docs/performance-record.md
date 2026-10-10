# The performance record

Ticket 24 owns PRD §4.4 and the §11 crash target. This file is the record it was
asked for: for each of the nine numbers, **what was measured, what it came to, and
what is still owed a device**.

Two other documents sit underneath this one and are not repeated here:
`docs/garden-performance-baseline.md` holds the frame-budget design and the DevTools
procedure, and `docs/battery-baseline.md` holds the drain method. This file is the
scoreboard.

**Take the numbers again with `./scripts/profile.sh`.** It runs the same benchmarks in
the same order and prints the same rows; `--size` adds a release Android build.

## Where the criteria stand

| PRD §4.4 | Target | Measured here | Needs a device |
|---|---|---|---|
| Garden render, 200 plants | 60fps, no drops | CPU-side frame work, **0.17 ms** with everything on | **Yes** — the frame itself |
| Cold launch to garden | < 1.5 s | The app's own share, and that it is flat in garden size | **Yes** — the OS's share |
| Battery, 25-min session | < 3 % | Nothing. Method documented | **Yes** — all of it |
| Timer accuracy, 120 min | ± 1 s | **Exact**, backgrounded and killed | Partly — that the OS delivers the alarm |
| Ambient loop seam | inaudible, < 5 ms | Click, gap and level, against the shipped files | Partly — a listener, and the final recordings |
| Release binary | < 50 MB | **30.6 MB** Android (arm64), with the final paper-cut art (ticket 35) | **Yes** — iOS |
| Memory over a long session | no growth | **Zero** `dart:ui` handles leaked | No |
| Profiling recorded | — | This file, and `scripts/profile.sh` | No |
| Crash-free rate | > 99.5 % of sessions | 100 sessions, nothing thrown | **Yes** — it is a field metric |

Read the last column as the honest summary: **two of the nine are closed. Five need a
device outright, two need one for the last part of the claim, and the binary-size row is
half closed** — Android measured, iOS unbuildable. The reasons are the same two
throughout: there is no iOS hardware, no Android hardware and no emulator here, and three
of the criteria name assets ticket 23 has not delivered.

## 1 · The frame budget

Taken on an Intel i7-8700T (4 cores, 8 GB), Flutter 3.44.8, **debug build**, host
`flutter test`. Averaged over 120 frames after a 20-frame warm-up; spread over three
runs. These extend the table in `docs/garden-performance-baseline.md` with the row
ticket 07 could not fill in.

| What | Per frame |
|---|---|
| 200 plants, still, whole garden visible | 0.21 – 0.25 ms |
| 200 plants, panning | 0.07 – 0.09 ms |
| **200 plants, panning *and swaying*** | **0.15 – 0.17 ms** |
| 200 plants, panning, swaying *and shimmering gold* (ticket 36) | 0.26 – 0.28 ms |
| 200 plants, zoomed all the way in (most culled) | 0.02 – 0.03 ms |
| 200 plants, dragged through the real widget tree | 2.5 – 3.1 ms |
| Baking the texture atlas — once, never per frame | 7.6 – 8.2 ms |

**The sway is the row this ticket added, and it is the answer to the question ticket 07
left open.** That ticket declined to put REQ-023's sway in the garden until somebody had
a number, on the grounds that a continuously animating screen is an expensive default to
choose blind. The number is now in hand: swaying takes the painter's own per-frame work
from 0.08 ms to 0.16 ms — it roughly doubles it, and it doubles it to **one per cent of
a 16.7 ms frame**. The sway ships. See ADR 0020.

The delta is two hundred `sin` calls and two hundred multiplies, and nothing else,
because the batch was already carrying a rotation field per quad and passing it zero.
`test/garden/garden_sway_test.dart` asserts that the swaying batch is the same length as
the still one, quad for quad, so this stays true.

**The golden garden (ticket 36) costs about 0.1 ms a frame on top of the sway**:
REQ-021's shimmer is a colour per quad in the same `drawAtlas` call, not a second draw,
and the enchanted willow's halo is one extra quad in the batch. Measured three times on
the same box as the rest of this table, on 2026-10-10: 0.260, 0.266 and 0.276 ms, against
0.158 – 0.178 ms for sway alone in the same runs. Under 2 % of a 16.7 ms frame.

**These are debug numbers and a debug build is not what ships.** Release AOT is typically
several times faster on Dart-side work, so read them as pessimistic arithmetic and as an
optimistic proxy for a phone — evidence that the per-frame work is small and does not
grow with the garden, and not a frame time. The device readings are still owed, and the
empty table for them is in `docs/garden-performance-baseline.md`.

## 2 · Cold launch

| What | Measured |
|---|---|
| Launch to a garden on screen, empty garden | 288 – 316 ms |
| Launch to a garden on screen, 200 plants | 327 – 353 ms |
| Atlas bakes during launch | **1**, either way |

Debug, host, and **not a cold launch** — there is no process start, no engine load and
no first rasterised frame in any of it. What it measures is the app's own share: opening
SQLite, reading the settings row, querying the plants, laying out the plots and baking
the texture.

**The finding is the delta, not the total.** Two hundred plants — four hundred and
seventy sessions of real use — cost about 40 ms more to launch than none. Launch is
essentially flat in the size of the garden, which is the property that decides whether a
user two years in still meets a 1.5-second budget, and it is a property a workstation can
check. `test/performance/cold_launch_test.dart` asserts it, along with the fact that the
first garden frame is the real garden rather than an empty one filled in a frame later.

**Still owed:** the device number, on a mid-range Android and an older iPhone, with a
seeded 200-plant garden. The procedure is in `docs/garden-performance-baseline.md`.

## 3 · Battery

**Nothing is measured.** This machine has no phone to drain.

`docs/battery-baseline.md` holds the method, and ticket 24 leaves it in place rather than
rewriting it: an idle control run, four consecutive 25-minute sessions starting between
80 % and 60 %, untethered for the percentage and `dumpsys battery unplug` for the
attribution. What that document describes is the *bare* backgrounded session, which was
ticket 06's claim. This ticket's criterion is the full stack — ambient sound playing, the
live surface up, the screen off — so the run to take is the same one with the bed
selected and REQ-033's switch on.

Three things this ticket knows that the baseline document did not, and which whoever
takes the reading should have:

- **The garden now animates continuously while it is on screen**, which it did not when
  the battery method was written. That is REQ-023's sway plus ticket 14's weather. It
  costs nothing in a backgrounded session — `TickerMode` stops it behind another tab and
  the app gets no frames at all in the background — but it does mean *the foreground* has
  no still state any more, and a user who leaves the garden tab up is now on a screen
  asking for 60 frames a second indefinitely. That is a foreground number PRD §4.4 does
  not budget and probably should.
- **Reduce Motion stops it dead.** `GardenView` stops the controller rather than ignoring
  it, so a phone asking for no animation is a garden asking for no frames.
- **The Android gap `docs/ambience.md` flagged for this ticket is still open**: nothing
  keeps the process alive for the ambient bed if the user turns REQ-033's foreground
  service off. It is recorded there, it is unchanged, and it is a decision rather than a
  bug — see *What is knowingly not done* below.

## 4 · Timer accuracy

**Exact, at every point a workstation can reach.**

| Case | Error |
|---|---|
| Two hours, suspended throughout, no Dart running | 0 |
| Two hours, process killed at 61 minutes and relaunched | 0 |
| Two hours, watched the whole way, ~990 frames, read off the ring | ≤ 1 s, which is the display's own rounding |
| Two hours, 6000 irregular polls (the domain's own test) | < 1 s at every poll |

Zero rather than *within a second*, and that is ADR 0001 rather than luck: elapsed time is
derived from a wall-clock anchor and never accumulated, so there is no counter to fall
behind. `test/performance/timer_accuracy_test.dart` asserts the app-level half —
including that the notice handed to the OS carries the same absolute instant — and
`session_machine_test.dart` the arithmetic.

The third row is the one measured the way §4.4 means it: parsed off the countdown the
user is looking at, not read out of the machine. It was mutation-checked — shifting the
formatter by three seconds fails it.

**Still owed:** that iOS and Android actually deliver the scheduled notification when they
said they would. A phone that sleeps through its own alarm, or an OEM battery manager that
defers it, is invisible to this suite. `docs/battery-baseline.md` has the Doze procedure
for provoking it.

## 5 · The ambient loop seam

**The measurement exists and passes; the assets it is measuring are placeholders.**

`test/ambience/bundled_audio_test.dart` measures the join three ways — the waveform step
across it against the 99.9th percentile of the file's own steps (a click), the RMS of the
first and last 50 ms against the file's own (a gap), and the level difference across it in
decibels (a pulse). It also asserts the beds are uncompressed PCM, which is the property
that makes a sample-accurate join possible at all; `docs/ambience.md` has the argument for
why AAC cannot meet the 5 ms budget on either platform.

The check is written against `AmbientSound.values` through `ambientLoopAsset`, so **it
applies to the real recordings automatically the moment ticket 23 delivers them.** Nothing
here needs changing when they land; the criterion needs re-running, and it needs a listener,
because no test can hear whether the *material* repeats noticeably.

**Still owed:** the final recordings, and a human ear. `docs/ambience.md` §"§5.4's sixty
seconds and §5.4's 8 MB cannot both hold" carries the recommendation for what to
commission — FLAC, mono, 44.1 kHz, twenty seconds a bed.

## 6 · Release binary size

**Android is measured and comfortably inside budget. iOS is not measurable here.**

Built with `flutter build apk --release --split-per-abi`, Flutter 3.44.8. **Re-taken by
ticket 35 on 2026-10-10 with the final paper-cut art**, which replaced the stand-ins; the
ticket 23 readings are kept beside them. See *The final art* below:

Sizes in **decimal MB**, which is the unit the stores quote and therefore the unit §4.4's
50 MB is in. (In MiB every row below is about 4 % smaller, which flatters the budget; the
conservative reading is the one recorded.)

| Artifact | Ticket 35 (final art) | Ticket 23 (stand-ins) | Is this the number? |
|---|---|---|---|
| `app-armeabi-v7a-release.apk` | **28.0 MB** | 26.7 MB | Close to it, for a 32-bit device |
| `app-arm64-v8a-release.apk` | **30.6 MB** | 29.3 MB | **Yes** — what nearly every real device downloads |
| `app-x86_64-release.apk` | 32.0 MB | 30.7 MB | Emulators only |
| `app-release.aab` | not re-taken | 29.1 MB | No — see below |
| `app-release.apk` (universal, all ABIs) | not re-taken | ~67 MB | **No.** Nobody downloads this; it is all three ABIs in one file |

**Read the per-ABI APK, not the bundle and not the fat APK.** Play delivers one ABI to a
device out of the bundle, so the arm64 split is the closest thing here to the Play delivery
size the PRD asks to be measured against. The `.aab` figure is also misleading in the other
direction: `--analyze-size` shows 12 MB of its 29.1 is `BUNDLE-METADATA` — debug symbols and
the obfuscation map — which Play strips and never ships.

### The final art

The paper-cut set (`tool/generate_sprite_art.dart`) is **1.8 MB** on disk against the
stand-ins' 0.36 MB, and the arm64 APK grew by **1.3 MB**, to 30.6 MB. That is the whole of
the art question ticket 23 left open: the watercolour was budgeted at 8–12 MB, and flat
paper compresses far better than soft washes, so the final art costs a fraction of that.
**19.4 MB of headroom remains** under the 50 MB budget. The art budget test still guards it
at 16 MB.

iOS is still unmeasured: it needs macOS (ticket 39).

### Where the 0.45 MB went

Ticket 24 recorded **28.8 MB** for arm64. The re-take is **29.3 MB**, and the difference is
neither drift nor noise: a clean rebuild (`flutter clean`, then the same command) came back
**byte-identical** to the incremental one, at 29,252,562 bytes. The build is reproducible
and the number really moved.

It moved because **ticket 24's reading predates `assets/art/` existing.** The stand-in art
set was written by `tool/generate_art.dart` after that measurement was taken, and it is 79
files that were not in the APK before:

| | |
|---|---|
| `assets/art/*` in the APK, uncompressed | 366,425 bytes |
| the same, compressed | **356,790 bytes** |
| observed growth since ticket 24's reading | 452,562 bytes |

The remaining ~96 KB is the asset manifest and zip alignment. So §6 as ticket 24 wrote it —
*every number above is with placeholder art, which is drawn from code and weighs nothing* —
was true when written and stopped being true the moment the stand-ins landed as files. The
sentence is corrected above and this is the arithmetic behind it.

**The thing worth taking from it is that the pipeline's weight is now visible in the
binary**, which is exactly what the stand-ins were for: 0.36 MB of flat shapes sits where
8–12 MB of watercolour will, and the delta between those two is the whole of what ticket
23's seventh criterion is about.

Where the bytes are, from `--analyze-size` on the arm64 bundle:

| | |
|---|---|
| `lib` (the Flutter engine and AOT snapshot) | 9 MB |
| `assets` | 6 MB |
| `dex` | 1 MB |
| of which, our own Dart code | 429 KB |

**The assets are the half we control, and they are the audio.** Six megabytes of the
binary is five uncompressed WAV beds; ticket 25's five end sounds add roughly another
megabyte across their two copies — see `docs/ambience.md` for why the beds are PCM, why
the end sounds' Flutter asset has to be as well, and what the alternatives cost. If the
budget ever gets tight, the beds are the dial, and moving them to FLAC is worth roughly
2 MB at no cost to the seam.

**Still owed: iOS.** It cannot be built here — it needs macOS and Xcode — and the number
that matters there is the **App Store thinned** size for a specific device, not the archive:
upload a build, then Xcode Organizer → the build → *Estimated App Store File Sizes*. The
20.7 MB of headroom Android has is a reasonable prior for iOS being fine, and it is a prior
rather than a measurement.

**This will move when ticket 23 lands.** Every number above is with the stand-in art, which
is ticket 04's flat shapes rasterised and compresses to 0.37 MB for the whole set. Real
watercolour is the one change most likely to spend the remaining headroom: soft gradients
run 150–400 KB a drawing, so seventy-eight files is plausibly 8–12 MB.

*One density, not three* — `docs/art-pipeline.md` explains why there are no `2.0x`/`3.0x`
variant folders and should not be, so the estimate above is the whole of it rather than a
third of it.

**The budget is now enforced rather than waited for.** `test/garden/art_delivery_test.dart`
weighs the delivered set on every run of the suite and fails above **16 MB** — the 20.7 MB
of headroom this table measures, less a margin for everything else still to grow. So a
delivery that would blow §4.4's 50 MB fails in CI, where the fix is compression, rather
than in a store's upload dialog. What still needs a real build is the binary itself, and
that is `./scripts/profile.sh --size` on the day the art lands.

## 7 · Memory

**Zero handles leaked, across every case that can be constructed here.**

`test/garden/garden_memory_test.dart` counts `dart:ui` `Image` and `Picture` allocations
through `Image.onCreate` / `onDispose`, which makes a leak an exact number rather than a
shape on a graph. The two are watched because they are where the bytes are: an atlas is
roughly two megabytes of native memory behind one handle, and it is not the garbage
collector's to reclaim.

| Case | Handles left open |
|---|---|
| One bake, one dispose | 0 |
| A hundred rebakes | 0 |
| 600 frames of a swaying, panning, 200-plant garden | 0 images, 0 pictures |
| Four times round the year — every season forced, ~150 bakes | ≤ 2 images |
| A long visit: 1200 animated frames, counted at 600 and again at 1200 | **no change between the two readings** |
| The app torn down | 0 |

The fifth row is the criterion as worded. An absolute count is a property of how many
layers happen to be on screen; *no growth over time* is a derivative, so it is measured as
one — twenty seconds of animation, sampled twice.

**Still owed:** a heap snapshot on a device, which would also cover Dart-side growth that
this cannot see. In practice the Dart side is collected and the native side is the risk,
which is the part that is covered.

## 8 · Crash-free rate

**Nothing threw, across a hundred sessions and three animated minutes of a full garden.**

`test/performance/soak_test.dart` drives a hundred sessions — every fourth paused and
resumed mid-session, every seventh suspended and brought back, every tenth followed by a
walk through the garden and the journal — and asserts after each one that nothing has
reached `FlutterError.onError`. A hundred is about seven weeks at §11's target usage and
is past every milestone REQ-021 awards, so the celebration overlay, the growing plot count
and the filling garden are all inside the run.

This is a sharper bar than §11's and a different one. **§11's 0.5 % is a field metric** —
its own row in the PRD says Xcode Organizer and Play vitals — and it cannot be produced by
any amount of local testing. What the soak does is the part worth doing first: prove that
the hundredth session behaves like the first, which is where a leaked listener, an
un-cancelled controller or a query that grows would show up.

**Still owed:** the actual criterion. It needs two stores, real installs and a release.

## What is knowingly not done

- **The reference Android device is still not named.** PRD §12's open question 8, flagged
  by ticket 07 as the thing that has to be settled before a frame-budget reading can be
  interpreted, and this ticket did not settle it either — it is a product decision about
  which phones the app supports, not a measurement. Every device-side criterion above is
  waiting on it.
- **A foreground battery budget does not exist.** §4.4 budgets drain *during a session*,
  which is the backgrounded case. The garden is now a continuously animating screen, and
  nothing anywhere says what it is allowed to cost to sit and look at your garden. Worth
  a number.
- **The ambient bed on Android can still be reclaimed** if the user turns REQ-033's
  foreground service off. `docs/ambience.md` raised this for ticket 24 and this ticket is
  leaving it: both fixes couple two features the user is deliberately offered separately —
  tying the bed to the foreground service, or adding `just_audio_background` and a second
  notification — and neither is a performance decision. It belongs to whoever owns the
  audio experience.
- **Hit-testing ignores the sway.** A tap on a leaning plant is tested against where the
  plant is standing, not where it is leaning. At two degrees this is about three pixels at
  the top of a tall sprite, and the alternative — a hit-test that depends on the instant
  the finger landed — is worse. Recorded rather than fixed.
