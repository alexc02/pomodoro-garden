# 35 — The full art set

**What to build:** everything ticket 28's generator was approved to draw. That means all **35 sprites** (6 plant types × 5 stages, plus the shared bonus set of 5), the decor objects, the scenery restyle, the app icon and the Play feature graphic. PRD v2.2 §9.1 and §8.1.1, step 8. This carries out most of what ticket 23 asked for, without an illustrator.

**Blocked by:** 28, with the owner's style decision recorded in it.

**Status:** done. The owner reviewed the full set on 2026-10-10 and asked for **no changes**, soil and sky included. Review page (private to the owner): https://claude.ai/code/artifact/d197d661-35ad-451a-abf5-a329fbe81bf1

- [x] All 35 plant sprites generated **in the paper-cut finish** (`tool/generate_sprite_art.dart`, chosen in ticket 28) with role masks; every placeholder in `assets/art/plants/` replaced; `manifest.json` footprints correct
- [x] The four decor objects (lantern, bench, birdbath, pond) generated in the same style
- [x] **Scenery restyled to paper-cut, still code-painted:** the soil tile as a cut-paper shape with a cast shadow (`GardenAtlas._paintSoil`), a fibre texture over the sky, petals, leaves and flakes as small paper cut-outs (`WeatherPainter`). Shown to the owner before moving on; the owner did not say in ticket 28 whether today's soil and sky looked wrong, so ask with the restyle on screen. The 12-row season × theme colour table and the 3-second crossfade are unchanged
- [x] App icon: the paper-cut seedling from PRD §5.1, replacing `_seedling` in `tool/generate_icons.dart`, every size re-generated for both platforms
- [x] Play feature graphic (1024×500) generated, kept outside the app bundle
- [x] `art_delivery_test.dart` green, including the 16 MB art budget; the Android release size re-measured against 50 MB and recorded in `docs/performance-record.md`
- [x] Comparison renders for the owner's spot-check: every type at all five stages, in all four seasons, in all three themes
- [x] `tool/generate_art.dart` no longer rewrites rows the sprite generator owns (it would overwrite them with placeholders), and `docs/art-pipeline.md` is updated for paper-cut and for the mask-strength finding in ticket 28
- [x] Ticket 23's open criteria ticked or annotated with what this ticket did
- [x] `flutter analyze --fatal-infos` clean; app and domain suites green

## What was built

| Where | What |
|---|---|
| `tool/sprite_art/parts.dart` | The shared pieces: soil, stalk, leaf (pointed or round), scalloped clump, blossom, bud. The flower was moved onto them and re-generates **byte-identical** |
| `tool/sprite_art/plants.dart` | Wildflower, herb, bush, small tree, large tree and the bonus tree at five stages, plus the icon's seedling |
| `tool/sprite_art/decor.dart` | Lantern, bench, birdbath and pond |
| `tool/generate_sprite_art.dart` | Now paints every plant type and every object, and owns every manifest row |
| `lib/src/garden/garden_atlas.dart` | Soil tiles as cut paper: a frame in the biome's material, a soft shadow, a sheet of soil on top, an irregular cut. Bare plots get a faint sheet |
| `lib/src/garden/season_weather.dart` | Petal, almond-leaf and six-pointed snowflake cut-outs, each with a small shadow |
| `lib/src/features/garden/garden_screen.dart` | The journal's `PaperPainter` fibres laid over the sky, behind the garden |
| `lib/src/garden/image_sprites.dart` | **Bug fix.** The decor mask's green channel meant water for the pond only, so any image birdbath showed lantern-glow water (true of the stand-ins too). Now it means glow for the lantern and water for everything else. `test/garden/image_decor_sprite_test.dart` paints real pixels and fails on the old rule |
| `tool/generate_icons.dart` | The paper-cut seedling, painted by the generator and tinted through `ImageSpriteArt`, at every Android density, the adaptive layers and all 15 iOS sizes |
| `tool/generate_store_art.dart` | The Play feature graphic, `docs/store/feature-graphic.png`, 1024 × 500, no text |
| `tool/render_art_preview.dart` | Every type × stage, the decor, a garden and its weather, for all 3 themes × 4 seasons |
| `tool/generate_art.dart` | **Retired**: its test is skipped with a reason, so it can't overwrite the art |
| `docs/art-pipeline.md`, `docs/performance-record.md`, `pubspec.yaml` | Rewritten for paper-cut and the generator; the mask-strength finding; the new binary size |

**Size:** the art is **1.8 MB** (budget 16 MB). The Android arm64 release APK is
**30.6 MB**, up 1.3 MB from 29.3 with the stand-ins, against a 50 MB budget.

**Suites:** 989 app tests and 396 domain tests at the last full run with every art and
renderer change in; analyzer clean.

**Verification gap:** the art has been judged on renders, not on a phone. Softness at
high density, the icon on a real launcher, and the paper textures at a phone's pixel
density need a device (ticket 39). iOS binary size needs macOS.
