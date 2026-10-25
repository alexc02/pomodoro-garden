# 28 — One-plant art test

**What to build:** the first version of the procedural watercolour generator, used to draw **one plant type through all five growth stages**, and shown in a real garden beside today's soil and sky. Its purpose is to answer one question before anything else is drawn: *does a generated watercolour look good enough to ship?* PRD v2.2 §9.1 and §8.1.1, step 1.

There is no illustrator (PRD v2.2 changelog). The art comes from code in this repo. No image-generation model is used: the store copy says "No AI".

**Blocked by:** nothing.

**Status:** done. Round 1 (watercolour) was **rejected by the owner**; round 2 showed the same flower in a paper-cut and a flat finish, and on 2026-10-10 the owner chose **paper-cut (A)**. `assets/art/plants/flower_*` now hold the paper-cut flower. Preview page (private to the owner): https://claude.ai/code/artifact/f023685d-53f2-4e06-9a72-0fdcb6a515d9

- [x] A generator in `tool/` that paints a sprite in a watercolour style: layered translucent washes, pigment pooling darker at the edges, paper grain and slightly irregular outlines. Deterministic: the same input always gives the same pixels
- [x] It writes each drawing **with its role mask** (`<name>.png` + `<name>.roles.png`), in the format `docs/art-pipeline.md` describes, so seasons and themes still recolour it
- [x] One plant type — the **flower** (the 25-minute default session grows it) — drawn at all five stages, replacing its placeholders in `assets/art/plants/` and its rows in `manifest.json`
- [x] The five stages read as one plant growing: the silhouette evolves, never shrinks and never wanders. `art_delivery_test.dart` stays green
- [x] A comparison render for the owner: the new flower in a seeded garden (`test/support/garden_seed.dart`) beside placeholder plants and today's soil and sky, in all four seasons, saved as PNGs outside `assets/`
- [x] **Owner decision recorded here:** watercolour rejected; **paper-cut chosen** over flat. The soil and sky question was not answered; ticket 35 asks it again with the restyled scenery on screen. Original criterion: (a) the style ships, proceed to ticket 35; or (b) switch to a style a generator does well (flat or paper-cut illustration) and redo this ticket. Also record whether today's soil and sky look wrong beside the new plant (PRD §9.1: they get restyled either way, but this sets how far)
- [x] `flutter analyze --fatal-infos` clean; app and domain suites green (959 and 383, run 2026-10-10 with ticket 30's changes in)

## Notes

- `tool/generate_art.dart` already rasterises the placeholders and writes the manifest. Extend it, or give the watercolour painter its own file beside it; either way the manifest stays the single source of truth.
- Watch the art budget: `art_delivery_test.dart` enforces 16 MB of art across the whole set. One plant's five stages should be well under a twentieth of that.

## What was built

| Where | What |
|---|---|
| `tool/sprite_art/wash.dart` | The engine, with three finishes (`Finish`): **paper-cut** (the app's style: flat layers, cut edges, a shadow cast wherever one layer lies on another, fibre texture), and the rejected watercolour and flat, kept for comparison. Shape helpers; a pure-Dart PNG encoder (the drawing must stay unpremultiplied) |
| `tool/sprite_art/flower.dart` | The flower at five stages. Leaves keep fixed places and seeds across stages, so the stages read as one plant |
| `tool/generate_sprite_art.dart` | `flutter test tool/generate_sprite_art.dart`: paints the types it owns in paper-cut (`FINISH=watercolour` or `flat` for the others) and rewrites only their manifest rows |
| `tool/render_art_preview.dart` | `flutter test tool/render_art_preview.dart`: close-up, stage strip and garden renders for each season, through the real tint, atlas and export path, into `.scratch/pip-garden/art-preview/` (or `PREVIEW_OUT`) |

No app code changed. The full suites pass with the paper-cut flower, `art_delivery_test.dart` included. The PRD's §5.1, §6.2, §9.1 and REQ-022 now say paper-cut.

## What was learned

- **The runtime tint mixes, it doesn't multiply.** (Learned on the watercolour round; it holds for every finish.) `ImageSpriteArt.paintTinted` lays the palette colour over the drawing with `srcATop`, at the mask's strength. A darker drawing pixel under a strong mask can come out *lighter* than its neighbours, so the first attempt's texture cancelled out. The fix is in the generator: the drawing carries value in sepia (from 0.95 down to 0.05), and the mask strength drops from 0.95 to 0.2 as pigment density rises, so pooled edges stay dark in every season. `docs/art-pipeline.md`'s "0.85 throughout" advice is wrong for watercolour and should be updated in ticket 35.
- **Species share one bloom hue.** `plantPaletteIn` only shifts the season's bloom colour slightly per species, so a sunflower is not yellow. That is existing behaviour, not something this ticket changed; raise it with the owner if it matters.
- **`tool/generate_art.dart` will overwrite the flower.** It rewrites every row of the manifest. Before anyone re-runs it, ticket 35 must make it skip the types the watercolour generator owns.
