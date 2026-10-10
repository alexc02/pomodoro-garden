# The 200-plant garden baseline

PRD §4.4 budgets the garden at **60fps with no dropped frames, with two hundred plants
on screen, on a mid-range Android device and an older supported iPhone**. Ticket 24 owns
meeting that number with everything switched on. This document owns the reading
underneath it: what ticket 07's garden costs before ambient audio, the live surface or
the real watercolour art exist. Ticket 14's seasons arrived after it and added the one
row and the one section that say so.

**The device readings are not taken.** Ticket 07 had no device — no iOS hardware, no
Android hardware, no emulator. What follows is what *was* measurable without one, the
method for the rest, and the empty table.

## What was measured, and what it is worth

`test/garden/garden_performance_test.dart` runs on a workstation, under `flutter test`,
against a garden of two hundred mature plants in two hundred plots. A widget test has no
GPU and no vsync, so **none of these numbers is a frame time**. What they measure is the
CPU-side work the garden asks for on every frame — walking the plots, culling the ones
off screen, building the `drawAtlas` batch and recording the draw — which is the part
this ticket wrote.

That is worth measuring on its own because it is the part a bad design gets wrong by
orders of magnitude rather than by a few per cent. Two hundred positioned widgets, or
two hundred `CustomPaint`s, or one painter asking each sprite to redraw itself from
circles every frame, would all show up here. The GPU-side cost — one textured quad batch,
four hundred quads, one texture bind — is the part that needs a device to be interesting,
and it is also the part this design exists to make boring.

### The readings

Taken on an Intel i7-8700T (4 cores available, 8 GB), Flutter 3.44.8, debug build, host
`flutter test`. Averaged over 120 frames after a 20-frame warm-up; three runs, spread
shown.

| What | Per frame |
|---|---|
| 200 plants, still, whole garden visible | 0.20 – 0.29 ms |
| 200 plants, panning a pixel per frame | 0.07 – 0.09 ms |
| 200 plants, zoomed all the way in (most of them culled) | 0.03 ms |
| 200 plants, dragged through the real widget tree — build, layout and paint for the whole tab | 2.2 – 2.4 ms |
| 200 plants, dragged, with REQ-019's snow falling over them | 2.1 – 2.6 ms |
| REQ-019's weather alone, one season | 0.06 – 0.14 ms |
| REQ-019's weather alone, two seasons crossfading (the worst case) | 0.06 – 0.15 ms |
| Baking the texture atlas — **once**, on launch and on a theme change, never per frame | 4.4 – 7.4 ms |

Read them in that order and the shape of the design is visible in the numbers. The
painter's own work is a fifth of a millisecond and *falls* when the garden moves,
because a moving camera culls more than a fitted one. Everything else on the row —
1.9ms of the 2.2 — is the widget tree around it, and it is flat in the number of
plants, because there is one widget whatever the garden holds.

The atlas bake is the one expensive thing here, and it is a one-off: it happens when the
view is first built and when the theme's colours change under it, which is a phone going
dark, ticket 14's seasons or ticket 19's themes. Nothing about panning, zooming or
planting rebakes it. If a later ticket makes the atlas rebuild per frame, this is the
number that will say so.

**A caveat that matters for ticket 24:** these are debug-build numbers, and a debug build
is not what ships. Release AOT is typically several times faster on Dart-side work. So
the workstation figures are pessimistic as arithmetic and optimistic as a proxy for a
phone; they are neither a floor nor a ceiling for the device reading, only evidence that
the per-frame work is small and does not grow with the garden.

## Taking the device readings

The target is the one PRD §4.4 names, and the honest way to take it is a **profile
build** on real hardware. `flutter test` cannot produce it and neither can a debug run —
debug builds drop frames on their own.

```sh
flutter run --profile
```

Then, with a full garden on screen:

- **The garden must actually be full.** Two hundred plants is four hundred and seventy
  completed sessions of real use. Seed them: `test/support/garden_seed.dart` writes a
  garden of any size through the real repositories, and the same code can be driven from
  a scratch `main` against the on-device database.
- **DevTools → Performance**, with "Track widget builds" off and the frame chart on.
  Record a ten-second pan across the whole garden at the zoom the garden opens at, and a
  second run zoomed all the way in. Read **UI thread** and **Raster thread** separately:
  this design deliberately moves work from the first to the second, and a total would
  hide whether that landed.
- **Then `flutter run --profile --trace-skia`** if the raster thread is the one over
  budget, which is where a texture too large for the device, or a filter quality too
  high, would show up.

What to expect, and what would be a finding:

| Reading | Expectation | If it is not |
|---|---|---|
| UI thread, panning | Well under 16.7ms; the workstation says the painter's share is a fraction of a millisecond | Something is rebuilding per frame that should not be — suspect the atlas first |
| Raster thread, panning | Under 16.7ms; it is one batch and one texture | Suspect the atlas's size against the device's texture limits, and `FilterQuality.medium` |
| First frame with a full garden | Under PRD §4.4's 1.5s launch budget | Suspect the bake, and the database read behind `gardenLayoutProvider` |

### The devices

PRD §10 asks specifically for an aggressive-OEM Android device (Xiaomi, Samsung or
Huawei) alongside whatever is convenient, and open question 8 in §11 is still open:
**the minimum Android device this budget is committed to has not been named.** The
performance budget means nothing until it is, and ticket 24 should close that before
taking a reading it cannot interpret.

| Device | OS | Build | UI thread, panning | Raster thread, panning | Dropped frames in 10s |
|---|---|---|---|---|---|
| | | | | | |

## What this ticket did about performance, so ticket 24 does not re-derive it

- **One draw call.** Every plot and every plant is one quad in a single
  `Canvas.drawAtlas`, cut from one texture baked out of the sprite registry. See
  `lib/src/garden/plant_atlas.dart`, and `test/garden/garden_painter_test.dart`, which
  asserts the batch really is one batch.
- **Depth sorting is arithmetic, not layering.** Plots come out of `GardenLayout`
  ordered by `x + y`, and the painter draws them in that order. Nothing in the widget
  tree is stacked.
- **Off-screen plots are culled.** The painter skips any plot whose centre falls outside
  the window, inflated by a sprite's height upwards and half its width sideways — a
  plant grows up out of its plot, so the margins are not symmetric. Zoomed in on a full
  garden this is the difference between 400 quads and about 30.
- **The atlas is memoised on its recipe.** `PlantAtlasRecipe` compares by value, so a
  rebuild that changed no colour rebakes nothing.
- **The garden's tab stops animating when it is not on screen.** `AppShell` wraps every
  tab in a `TickerMode`; the garden's entry animation, ticket 14's season crossfade and
  ticket 14's weather are the tickers on this screen, and none of them runs behind
  another tab. The weather's is not started at all in a season with nothing falling in
  it, because a ticker with no work still asks for a frame every vsync.

## What ticket 14 added, and what it cost

REQ-019's seasons are colours and a particle overlay, and both were built against the
numbers above rather than beside them.

- **The weather is capped, not emergent.** `SeasonParticles.countIn` derives a count from
  the window's area and then takes the smaller of that and `SeasonParticles.maximum`, so
  the overlay is a fixed number of canvas primitives however large the window. On a phone
  that is 35 flakes in winter and around 20 in the other two seasons. The two weather rows
  in the table above are the whole of what it costs — a rounding error against the garden's
  own 0.2ms, and budgeted rather than merely recorded, including the two-layer crossfade
  that is the one moment the per-season cap can be exceeded.
- **The atlas has a floor on how often it may be rebaked.** A season crossfades over
  three seconds and moves the soil colour every frame of it; the atlas is baked from the
  soil colour. Without a floor that is 180 bakes — the most expensive row in the table,
  180 times, inside three seconds. `GardenView.rebakeInterval` holds it to one every
  250ms, so the texture steps through the change while the sky crossfades smoothly over
  it, and the last step lands on whatever the theme settled at.
  `test/garden/season_test.dart` asserts the bound and was verified to go red without it.
- **Summer costs nothing at all.** No particles, no ticker, and the overlay returns
  `SizedBox.shrink()` rather than an empty painter.

## The one thing knowingly left for ticket 24 — since settled

REQ-023's ambient sway was on the timer screen and **not in the garden**. It was left out
because a swaying garden is a continuously animating screen, and putting one in before the
frame budget had ever been measured was choosing the expensive default blind; ticket 24 was
asked to decide it with a number in hand.

**Ticket 24 measured it and shipped it.** Swaying takes the painter's own per-frame work
from 0.07–0.09 ms to 0.15–0.17 ms — about one per cent of a 16.7 ms frame — for exactly
the reason predicted above: the batch already carried a rotation per quad, so the cost is
one `sin` per visible plant and no structural change. No extra quad, no extra draw call,
no widget.

The decision and what it costs are in `docs/adr/0020-the-garden-sways-in-the-batch.md`;
the numbers are in `docs/performance-record.md`, which is the scoreboard for all nine of
ticket 24's criteria and supersedes this document's device table below.

**One consequence belongs here, next to the numbers above.** The garden is now a screen
that never stops animating while it is on top. `TickerMode` still stops it behind another
tab and Reduce Motion stops it outright, and a backgrounded session is untouched because
the app gets no frames at all — but PRD §4.4 budgets no *foreground* drain, and there is
now something to budget.
