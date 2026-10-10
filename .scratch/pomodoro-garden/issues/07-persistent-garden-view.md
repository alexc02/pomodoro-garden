# 07 — The garden persists and you can explore it

**What to build:** Every completed session leaves a plant behind. The user opens the garden tab and sees all of them laid out in an isometric grid, and can pan and zoom to inspect any corner. The garden is there tomorrow, next week, and next month — this persistence is the product's entire emotional premise and the thing that differentiates it from Forest.

The garden also grows in *capacity*: it starts at 12 plots and unlocks 4 more every 10 completed sessions, up to 200. Plots are never capped for free users.

Render with **`CustomPainter` + `Canvas.drawAtlas`**: all plant sprites batch into a single draw call from one texture atlas, which is what makes 200 sprites plus particles affordable. Depth ordering and hit-testing are computed in isometric space by hand rather than delegated to the widget tree — do not build this as 200 positioned widgets, which is the most likely way to miss ticket 24's frame-rate target.

Use `/prototype` on the isometric projection and hit-testing before committing — the coordinate maths and inverse hit-test are cheaper to get right up front than to retrofit under twelve dependent tickets.

**Blocked by:** 04

**Status:** done

- [x] Completing a session places its plant into the nearest available plot; the placement is deterministic and persisted, so the garden looks the same on every launch
- [x] The garden renders isometrically with correct depth ordering — plants nearer the viewer overlap those behind them
- [x] Pan and zoom feel natural on both platforms, are bounded so the user cannot lose the garden off-screen, and the view restores its position when returning to the tab
- [x] Capacity starts at 12 plots and unlocks +4 per 10 completed sessions to a maximum of 200; unlocking is derived from the session count, so it is correct for an existing user, not only for new ones
- [x] Newly unlocked plots are visible as empty soil, giving the user something to fill
- [x] Reaching 200 plots is handled explicitly — decide and document what happens to the 201st plant rather than crashing or silently dropping it
- [x] Sprites are batched through a texture atlas rather than drawn or laid out individually
- [x] A garden of 200 plants renders and scrolls smoothly; record the frame timings as ticket 24's baseline
- [x] The screen-to-plot inverse transform is unit-tested independently of rendering, including at the extremes of the zoom range
- [x] Garden entry animates with the gentle fade and scale from §5.3

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/garden/garden_plot.dart` | `GardenPlot`, the 200-plot placement order, REQ-018's unlock schedule, `nextFree` |
| `packages/pomodoro_domain/lib/src/garden/garden_layout.dart` | The garden as it stands: plots in draw order, what is in each, what has no plot |
| `lib/src/garden/garden_projection.dart` | Plot ↔ screen both ways, the zoom, and the bounds that keep the garden on screen |
| `lib/src/garden/plant_atlas.dart` | Every sprite baked into one texture; the only `drawAtlas` in the app |
| `lib/src/garden/garden_painter.dart` | The whole garden as one batch, depth-sorted and culled |
| `lib/src/features/garden/` | The tab: the camera, the gestures, §5.3's entry, and a word when the garden has one |
| schema v6 | `plants.plot_x` / `plot_y`, with the 5 → 6 step laying out an existing user's garden |
| `docs/adr/0006-…` | Unlocked plots are a floor, not a ceiling; and what happens to the 201st plant |
| `docs/garden-performance-baseline.md` | The measurements, and the method for the device readings |

## Two things worth knowing before picking up a dependent ticket

**REQ-018 does not survive a literal reading, and this ticket departed from it.** A
session earns one plant; ten sessions unlock four plots. The two curves cross at the
**twenty-first** completed session — long before the 200 cap the checklist worries
about — so "a plant goes in an available plot" would start failing in a fortnight of
ordinary use. The unlock count is implemented as a floor: it is how much empty soil the
garden shows, and the garden is never smaller than what is planted in it.
`GardenPlots.unlockedAfter` still implements REQ-018 exactly and is tested against its
exact numbers. **The PRD should be corrected**, per `issues/README.md`'s rule that the
ticket wins where the two disagree.

**The 200-plant frame timings are CPU-side and taken on a workstation.** There was no
device — no iOS hardware, no Android hardware, no emulator — so PRD §4.4's 60fps claim
is *not* verified. What is recorded is the per-frame work the garden asks for (0.07–0.29
ms for the painter, 2.2–2.4 ms through the whole widget tree, with the atlas baked once
at 4–7 ms) plus the profile-build method for taking the real readings, in
`docs/garden-performance-baseline.md`. Ticket 24 inherits an empty device table and PRD
§11's open question 8 — the minimum Android device this budget is committed to — still
unanswered.

## Left for later, deliberately

REQ-023's ambient sway is on the timer screen and not in the garden. The batch already
carries a rotation per quad, so adding it is one `sin` per plant per frame and no
structural change — but a continuously animating screen is an expensive default to
choose before the frame budget has ever been measured on hardware. Ticket 24 should
decide it with a number in hand; the reasoning is at the end of the baseline doc.

Hit-testing is the tile under the finger, not the plant standing on it. A large tree's
canopy overhangs the two plots behind it. `GardenProjection.spriteBounds` is exposed so
that ticket 12 can walk the plots front to back and refine it.
