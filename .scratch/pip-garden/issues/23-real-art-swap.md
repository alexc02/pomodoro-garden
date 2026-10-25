# 23 — Swap in the real watercolour art

> **PRD v2.2:** there is no illustrator. The art is now generated in this repo by tickets **28** (style test: watercolour rejected, **paper-cut** chosen) and **35** (the full set, the scenery restyle, the icon and the feature graphic). The 35-sprite count this ticket argued for is what was drawn. Criteria 1, 2, 4 and 6 are carried out by ticket 35; 5 (softness) and 7 (420 combinations by eye) now rest on the owner's review of ticket 35's page and on ticket 39's device pass.

**What to build:** Every placeholder shape is replaced by the final hand-drawn watercolour illustrations, and the app looks like the product the PRD describes. Because everything upstream was built against the sprite registry from ticket 04, this ticket adds assets and changes no logic.

If art is late, this is the only ticket that slips — that is the whole point of the placeholder strategy.

**Blocked by:** 04, 12, 13, 19

**Status:** **not done, and cannot be closed here — the art does not exist.** PRD §9.1 commissions the illustrations from a freelance illustrator; that delivery has not arrived, and it is not something this repository can produce. `assets/art/` holds ticket 04's stand-ins. Art is late, and this ticket is the one that slips — which the ticket's own second paragraph says is the point.

One criterion is fully closed. Four are taken as far as anything short of the delivery can take them, and each now has a **check that will catch the way it fails** rather than a note asking somebody to remember to look. Three are not started and cannot be. A criterion is ticked below only when nothing further is owed it.

What *was* built is the acceptance half of the pipeline: `test/garden/art_delivery_test.dart`, which measures a delivery against criteria 5, 6 and 7 on every run of the suite. Writing it found the shipped manifest's footprints to be wrong in all thirty-nine rows — see **Two defects found and fixed**. The Dart side is 12 new app tests and none in the domain core: **957 and 384**, against 945 and 384 before, with `flutter analyze --fatal-infos` clean.

- [ ] All 6 plant types × 5 stages, and all 7 bonus plants × 5 stages, delivered and wired through the existing registry — **the wiring is done and exercised; the drawings do not exist.** Also **the count is wrong: it is 35, not 65** — see *The count this ticket asks for is a third too high*
- [ ] Soil/plot tiles, seasonal overlays, theme backgrounds and decor art replaced — **decor is wired; the other three have no art seam at all**, and building one is the logic change the next criterion forbids. See *Criteria 2 and 3 contradict each other*
- [x] No growth, placement or timer logic is modified by this ticket — it is assets and registry entries only — **enforced, not merely observed**: `sprites_are_the_only_art_test.dart` fails the build if any widget names an image, and `art_pipeline_test.dart` runs the real app with the art turned on and asserts the atlas, the batch, the hit-test and the timer screen are unchanged. The one unavoidable exception, `ArtGate`, was built with ticket 04's seam and is documented as such
- [ ] App icon and store assets shipped for both platforms, including all required Android density and adaptive-icon variants and the full iOS icon set — **the icon sets are complete and shipped; the mark on them is provisional, and no store asset exists.** See *Verification gaps*
- [ ] Assets are correctly scaled for the density range of both platforms with no visible softness on a high-DPI device and no jagged edges on transparency — **jagged edges are now a failing test; softness needs a phone.** See *Verification gaps*
- [ ] Growth-stage transitions still read as continuous growth with the real art — silhouettes should evolve, not jump — **"never shrinks, never wanders" is now a failing test; "evolves" needs eyes**
- [ ] Binary size after the swap is measured against the 50 MB budget, with compression applied as needed — **the budget is now enforced in CI at 16 MB of art**; the reading after the swap needs the swap, and iOS needs macOS
- [ ] Every plant type is visually inspected at all five stages in all four seasons across all three themes — **420 combinations, needing art, a device and a person.** Not started

## What was built

| Where | What |
|---|---|
| `test/garden/art_delivery_test.dart` | **New.** The delivery's acceptance criteria, as twelve tests over whatever is in `assets/art/` |
| `tool/generate_art.dart` | Footprints scanned from the rasterised PNG instead of taken from the sprite — see below |
| `assets/art/manifest.json` | Regenerated; all 39 footprints corrected |
| `lib/src/garden/art_bundle.dart` | A doc reference to a script that was never written, pointed at the test that does the job |
| `docs/art-pipeline.md` | *Checking a delivery* rewritten; **What has no seam to swap** added |
| `docs/performance-record.md` | §6: the density claim corrected, and the art budget recorded as enforced rather than awaited |

### The checker is the deliverable

`art_bundle_test.dart` already asked whether the *pipeline* works — does every plant resolve, does it draw anything, does the palette reach it. It would pass on thirty-five copies of the same smudge. What nothing asked was whether a **delivery had been prepared correctly**, and that is the question that gets asked once, on a day when a folder of PNGs arrives and somebody has to say yes or no.

Most of the ways that folder can be wrong are invisible until production:

| Failure | What it looks like | Who would have caught it |
|---|---|---|
| A footprint that disagrees with its drawing | nothing. Ticket 12 hit-tests the wrong box | nobody |
| Art centred in its box instead of standing on the bottom edge | a garden of levitating plants, on a device | a person, eventually |
| Alpha thresholded on export | criterion 5's *jagged edges*, at 3× zoom | a person, at 3× zoom |
| A plant shipped without its role mask | that one plant not turning in October | a person, in October |
| Art delivered below 264 px | criterion 5's *softness* | a person, on a phone |
| A drawing exported onto a matte | a plant standing in a white card | a person |
| A stage drawn smaller than the last | criterion 6's *jump* | a person, mid-session |
| The set weighing 30 MB | criterion 7, in a store's upload dialog | the store |

Every row is now a test with the file's name in its failure message. That is the whole of what could be built before the art arrives, and it is worth more than a checklist because it cannot be forgotten.

## Two defects found and fixed

**Every footprint in the shipped manifest was wrong.** `tool/generate_art.dart` took each one from the sprite's `footprintIn`, and a `PlantSprite` is explicitly entitled to say it overhangs its box — ticket 04's large tree claims to reach 5% above and below its square. A rasterised PNG cannot: the raster clips it. So all thirty-nine rows described ink that was not in the file, by up to 5% of a sprite's height, and `ImageSpriteArt.footprintIn` scales exactly those numbers into ticket 12's hit-test. The generator now scans the alpha channel of the PNG it just wrote — which is also what the illustrator's delivery has to do, so the stand-ins go through the same step the real art will instead of through a shortcut only they have.

Small in effect and worth naming in kind: it is the exact failure the footprint field exists to prevent, it was in the shipping asset, and no test in a suite of 945 would have found it. The check that found it is the first one in the new file.

**`art_bundle.dart` pointed at a script that was never written.** Its `ArtManifest` doc named `scripts/check_art.dart` as the thing that would tell a human what a delivery was missing. There is no such file. It now names `test/garden/art_delivery_test.dart`, which is that tool and runs unprompted.

## The count this ticket asks for is a third too high

The first criterion asks for *6 plant types × 5 stages, and all 7 bonus plants × 5 stages* — 65 drawings. **The app needs 35**, and this is a saving of roughly a third of PRD §9.1's illustration budget rather than a corner being cut.

REQ-021's bonus plants are a single `PlantType.bonus` whose seven varieties are seven *species*, and species is a **palette** difference, not a drawing — which is what the role mask exists to make possible, and how one basil differs from one mint without the registry knowing what basil is. The registry has been keyed by `(type, stage)` and by nothing else since ticket 04, deliberately; `plant_sprite.dart` spells out why.

Delivering 65 would mean re-keying the registry by species, which is the logic change the third criterion forbids. Either the count is wrong or the architecture is. The architecture is the one that has shipped.

**One thing that follows from it, and is a real acceptance criterion**: seven species sharing five drawings is fine, and `PlantType.bonus` sharing `PlantType.largeTree`'s drawings is not. The stand-ins do exactly that at four stages of five, because ticket 04 built the placeholder that way. A milestone reward that looks like an ordinary oak is not a reward. This is the one criterion below that stays a human's job, because the stand-ins cannot support a test for it — recorded in `docs/art-pipeline.md`.

## Criteria 2 and 3 contradict each other

The second criterion asks for *soil/plot tiles, seasonal overlays, theme backgrounds and decor art* to be replaced. **One of the four can be. The other three have nowhere to put a drawing.**

| | Drawn today by | Art seam |
|---|---|---|
| Decor | `ImageDecorSprite`, through `DecorSpriteRegistry` | **yes**, and wired |
| Soil / plot tiles | `GardenAtlas._paintSoil` — a diamond and a ring, from `GardenColors.soil` | none |
| Theme backgrounds | a colour off `GardenColors`, one per skin | none |
| Seasonal overlays | `WeatherPainter` — petals, leaves and flakes as canvas primitives | none |

None of the three is an oversight. Each was built as *colour applied to a shape* so that ticket 14's four seasons and ticket 19's three biomes could be twelve rows in a table rather than twelve sets of pictures, and so a season change could crossfade over three seconds by interpolating colours rather than dissolving between images. Giving them an art seam means an atlas that bakes a delivered tile, a background layer under the projection, and a weather overlay that blits sprites — renderer work, and precisely the change the third criterion forbids.

So this is a product question, not a bug: **is a watercolour soil tile worth a renderer change, or is a tinted shape under real watercolour plants the right look anyway?** Nobody can answer it yet, because the plants that would sit on that soil are not drawn. Recorded in `docs/art-pipeline.md` rather than guessed at here.

## Verification gaps

Everything here is waiting on one of two things, and neither is more software.

**Waiting on the delivery** — criteria 1, 2 and 8, and the second half of 5, 6 and 7. The art is a delivery from outside this repository. What could be prepared for it *was*: the pipeline is real and carries real files at real decode cost (`art_bundle.dart`, `image_sprites.dart`), the swap itself is two provider lines and is exercised end to end through the running app (`art_pipeline_test.dart`), and the acceptance criteria are written down as tests that will run against the delivery the hour it lands.

**Waiting on hardware** — this machine has no iOS device, no Android device, no emulator and no Xcode, which is tickets 06, 08, 19, 20, 21 and 24's gap inherited.

- **No visible softness on a high-DPI device (criterion 5).** The checker now enforces that art arrives at 264 px or better, which is the top of what anything asks for. It cannot enforce the thing most likely to actually fail: `GardenAtlas` bakes every sprite into a **192-pixel cell**, and the garden at maximum zoom on a 3× phone draws that cell at about 660 device pixels — a 3.4× magnification, and a property of the atlas rather than of the source art. It has never mattered because flat colour magnifies invisibly. **Watercolour will not.** The lever is `GardenAtlas.cellWidth`, at the cost of texture memory, and the decision needs somebody looking at a phone.
- **Silhouettes evolve rather than jump (criterion 6).** Arithmetic now says a plant never shrinks, never narrows, never shortens and never wanders off the spot it is rooted to, at every step from sprout to mature. Whether five drawings read as one plant growing is a judgement, and it needs eyes.
- **420 combinations inspected (criterion 8).** 7 types × 5 stages × 4 seasons × 3 themes. Ticket 19 already carries the smaller version of this gap — twelve skins designed, asserted and never looked at — and this is that gap multiplied by the art. It needs the delivery, a device and a person, in that order.
- **The icon mark is provisional (criterion 4).** `tool/generate_icons.dart` ships every file both stores require — five Android densities, the adaptive foreground and background layers at 108dp with the foreground inside the safe 66dp, `mipmap-anydpi-v26/ic_launcher.xml`, and all fifteen iOS sizes — and every one is derived from a single `_seedling` function. When PRD §5.1's watercolour seedling arrives, that function becomes a blit of the delivered 1024×1024 and the tool is run again. **Nothing has been seen on a launcher.**
- **No store asset exists (criterion 4).** The Play feature graphic, the App Store screenshots and REQ's alternate icons are not built and are outside this pipeline. Screenshots need a running app on a device; alternate icons are an iOS-only capability, because Android cannot swap launcher icons cleanly.
- **Binary size after the swap (criterion 7).** Android arm64 is measured at **29.3 MB** against §4.4's 50 MB, with the stand-ins' 0.36 MB inside it — 20.7 MB of headroom. The art set is now weighed on every run of the suite and fails above **16 MB**, so a delivery that would blow the budget fails in CI rather than in an upload dialog. The reading *after* the swap needs the swap; `./scripts/profile.sh --size` is the command. **iOS is still owed** and cannot be built here: it needs macOS, and the number that matters is the App Store thinned size for a specific device.

## What to do on the day the art lands

1. Drop the drawings and masks into `assets/art/`, write the manifest rows, and run `flutter test test/garden/art_bundle_test.dart test/garden/art_delivery_test.dart`. That answers criteria 1, 5 and 6 as far as arithmetic reaches, and 7 for the assets.
2. Flip `withArt` on in the app the way `art_pipeline_test.dart` does — two provider lines, and nothing above them.
3. Check by eye the one thing no test can: **that no two plant types share a drawing**, `bonus` and `largeTree` in particular.
4. Replace `_seedling` in `tool/generate_icons.dart` with a blit of the delivered 1024×1024 and re-run it.
5. Take the two readings that need hardware: `./scripts/profile.sh --size`, and a look at a mature tree at maximum zoom on a 3× phone.
6. Answer the soil/background question in *Criteria 2 and 3 contradict each other*, with real plants on screen to answer it against.
