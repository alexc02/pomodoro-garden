# 0020 — The garden sways in the batch

**Status:** accepted, ticket 24

## The question

REQ-023 and §5.3 ask for one continuous motion: *a mature plant leans two
degrees on a four-second loop, offset per plant.* It has been on the timer
screen since ticket 04, where one plant leans through `PlantPainter`.

Ticket 07 deliberately did not put it in the garden, and said so in as many
words in `docs/garden-performance-baseline.md`:

> It was left out because a swaying garden is a continuously animating screen,
> and putting one in before the frame budget has ever been measured on a device
> is choosing the expensive default blind. Ticket 24 should decide it with a
> number in hand.

So this ticket inherits two questions. **Can the garden afford to sway**, and if
it can, **what drives it** — because two hundred plants is exactly the scale at
which the obvious answers stop working.

## The decision

**The sway is a field of the transform the batch was already carrying, driven by
one controller, and the painter listens to it rather than being rebuilt by it.**

Three parts, and each of them rules out a plausible alternative.

**One quad, not one widget.** `Canvas.drawAtlas` takes an `RSTransform` per
quad, and an `RSTransform` is a rotation, a scale and a translation. The garden
has been passing `rotation: 0` since ticket 07. A leaning plant fills it in. So
two hundred swaying plants is the same four hundred quads, in the same single
draw call, with two hundred `sin` calls added — and `garden_sway_test.dart`
asserts the two batches are the same length, quad for quad, so it stays that
way. The rejected alternative is two hundred `Transform` widgets, which is the
design ticket 07 built the whole atlas to avoid.

**One controller, not one per plant.** `GrowingPlant` has a ticker of its own
because it draws one plant. Two hundred tickers all asking for the same vsync is
two hundred times the bookkeeping for one frame. Instead there is a single
`AnimationController` on `GardenView` repeating over 0..1, and each plant's
offset within the loop comes from `PlantSway.phaseOf`, seeded from the session
that grew it. Because the seed is the plant's identity rather than a `Random`,
the phase is decided once and survives every rebuild — a garden scrolled away
from and back comes back mid-lean where it was.

**A `repaint`, not a `setState`.** The painter takes the controller as an
`Animation<double>` and hands it to `CustomPainter`'s `repaint`. A frame of the
sway is then a repaint and nothing else: no build, no layout, no widget touched.
Had the painter taken a `double` instead, every frame would need a new painter,
which needs a `setState`, which rebuilds and re-lays-out the entire garden tab
sixty times a second to move some pixels.

**And it is stopped, not ignored, when the phone asks for stillness.**
`MediaQuery.disableAnimationsOf` turns the controller off and returns it to
zero, so a user who asked for no motion gets a garden that is upright and a
screen that is not asking for frames. Merely passing `null` to the painter would
have left a controller running to produce a still picture.

## Why it was affordable

The number ticket 07 asked for, from `docs/performance-record.md`:

| | Per frame |
|---|---|
| 200 plants, panning | 0.07 – 0.09 ms |
| 200 plants, panning **and swaying** | 0.15 – 0.17 ms |

It roughly doubles the painter's own work, and it doubles it to about **one per
cent of a 16.7 ms frame**. Those are debug-build workstation numbers and not
frame times — the caveats are in the record — but the shape is not in doubt: the
delta is arithmetic proportional to the number of visible plants, with no
allocation, no extra draw call and no widget.

## What it costs

**The garden is now a continuously animating screen, and it was not before.**
That is the real price, and it is a battery price rather than a frame-rate one.
Three things bound it:

- `TickerMode` stops it behind another tab — the shell already wraps every tab,
  which is how ticket 14's weather is stopped.
- The app gets no frames at all in the background, so a backgrounded session is
  unaffected and PRD §4.4's drain budget is untouched.
- Reduce Motion stops it outright.

What is left is the foreground case: a user sitting looking at their garden is
now on a screen asking for sixty frames a second indefinitely. Before this
ticket that was already true in three seasons out of four, because ticket 14's
weather animates; what changes is that it is now true in summer as well.
**§4.4 does not budget the foreground at all**, and `docs/performance-record.md`
records that as a gap worth a number rather than pretending this ticket closed
it.

**And `pumpAndSettle` is now unusable on a launched app.** The app opens on the
garden, and a repeating ticker never settles. The test harness has had `settle`
for exactly this reason since the timer screen started swaying; ticket 24 widened
its documentation from a warning about one screen to a rule about all of them,
and converted the one test that had not got the memo.

## What was rejected

**Swaying only the plants near the camera.** Culling the motion rather than the
quad — leaving distant plants still — would save `sin` calls that are not worth
saving, and it would put a visible boundary in the middle of the garden where
motion stops.

**Deriving the phase from the plot instead of the session.** Cheaper, and wrong:
the plant a user watched grow on the timer would lean to a different rhythm once
it reached the garden, because `GrowingPlant` seeds from the session. Two
renderers of one motion have to agree, which is why `PlantSway` exists as a
third thing both of them ask rather than as an arithmetic each of them repeats.

**Swaying REQ-036's decor.** A bench does not sway and a pond cannot. The
rotation is filled in for plants and passed zero for everything else.

## What this does not fix

A tap is hit-tested against where a plant *stands*, not where it is leaning. At
two degrees that is about three pixels at the top of the tallest sprite. The
alternative — a hit-test that depends on the instant the finger landed — is a
worse thing to have, so this is recorded rather than fixed.
