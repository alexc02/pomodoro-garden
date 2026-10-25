# 36 — The willow glows and the golden garden shimmers

**What to build:** REQ-021's two special effects. The **enchanted willow** (500 sessions) carries a soft halo of light behind it. Once the **golden garden** (1000 sessions) is earned, every plant in the garden takes a slow, gentle brightness shimmer, each on its own phase. PRD v2.2 REQ-021. Found by the gap review (finding A2): both plants are awarded today, but neither looks any different.

**Blocked by:** 35. The effects are tuned against the final art.

**Status:** done.

- [x] The willow's halo is a sprite in the garden atlas, drawn behind the willow in the same batch, so there is no second draw call (ADR 0020)
- [x] The shimmer modulates each plant's colour through the atlas's per-sprite colour, phase-randomised per plant as REQ-023's sway is, so the garden never pulses in unison
- [x] Both hold still under the system's reduce-motion setting: a static halo and a static warm tint
- [x] The shimmer applies to the garden only, not to the plant card or the timer screen
- [x] The garden export (REQ-035) includes the halo and a still frame of the tint
- [x] A **debug-only** control, beside the debug season picker in Settings, previews a garden at 500 and at 1000 sessions without writing anything to the database; compiled out of release builds
- [x] The 200-plant frame-time proxy in `docs/performance-record.md` is re-measured with the shimmer on and stays within budget
- [x] `flutter analyze --fatal-infos` clean; app and domain suites green

## What was built

| Where | What |
|---|---|
| `lib/src/garden/golden_shimmer.dart` | **New.** The shimmer: a warm gold (`#F2C14E`) wash per plant, 8–26 % while the garden moves on a phase of its own per plant, a steady 18 % when held still; and `earnedBy`, true once the 1000-session plant is in the garden |
| `lib/src/garden/garden_atlas.dart` | One more cell, `glowHalo`: a soft radial light baked from the season's glow colour. `drawInto` takes per-quad colours, in the same `drawAtlas` call, with `BlendMode.dstATop` |
| `lib/src/garden/garden_painter.dart` | A halo quad behind the enchanted willow (25 % larger, no lean); a colour per quad once the golden garden is earned — plants get the gold, soil and decor get transparent. A garden without it passes no colours at all |
| `lib/src/garden/garden_providers.dart` | `milestonePreviewProvider`: a debug-only preview that lays the 500 and 1000 awards into the garden on screen without writing anything. Release builds compile the read out |
| `lib/src/features/settings/settings_screen.dart` | **Milestone effects (debug)**: Off / 500 · willow / 1000 · golden, beside the debug season picker |
| `test/garden/garden_glow_test.dart` | **New**, 9 tests: the halo (behind, larger, willow only, holds still), the shimmer (earned only at 1000, no colours otherwise, gold on plants only, glints not in unison, adds no quad) and a **pixel test** that the soil is untouched and a plant turns warmer without fading |
| `test/garden/milestone_preview_test.dart` | **New**, 3 tests: 500 shows the willow, 1000 adds the golden garden, nothing is written and Off restores |
| `test/garden/garden_performance_test.dart` | A frame-time row with the shimmer on |

**Found and fixed while building it:** `drawAtlas` blends with the colour as the
*destination*. `BlendMode.srcATop`, the obvious choice, kept the tint's alpha and faded the
whole garden to near-transparent. `dstATop` is right, and the pixel test fails on the
wrong one (checked by putting it back).

**Fixtures corrected:** `garden_sway_test.dart` and `garden_performance_test.dart` gave
*session* plants the seven bonus species, which the app never does; with the halo that
made their quad counts wrong. They now cycle through session species only.

**Cost:** 0.26–0.28 ms a frame with sway and shimmer, against 0.16–0.18 ms with sway alone
(three runs; `docs/performance-record.md` §1). Under 2 % of a 16.7 ms frame.

**Export:** the export draws through the same painter held still, so an exported golden
garden carries the steady wash, and an exported willow its halo.

Suites: 1002 app and 396 domain tests pass; analyzer clean.

**Verification gap:** the shimmer's motion and the halo's softness on a phone screen
(ticket 39). Use the debug preview to see them.
