# 21 — Export your garden as an image

> ⚠️ **Amended by the v2.1 decision that the app is free.**
> The watermark is gone. *Free export carries a small tasteful corner watermark; premium
> export has none* is void — there is one kind of export and it is the clean one, so
> `garden_watermark.dart`, `GardenExport.watermarked` and the pixel test that compared
> the two are deleted. *`garden_exported` is emitted with premium status* is now emitted
> with no parameters. The rest of the ticket — that an export is **drawn** rather than
> captured — is untouched.
> See `docs/adr/0021-the-app-is-free-and-sells-nothing.md` and PRD §3.6.

**What to build:** The user taps export and gets a high-resolution image of their whole garden in the platform share sheet — ready for Instagram, a group chat, or their own wallpaper. Free users get a small corner watermark; premium users get it clean.

**Blocked by:** 07, 18

**Status:** done — every criterion is built and covered, with the qualifications named on their own lines below. **No Swift or Kotlin was compiled and no image has been looked at**: this machine has no Xcode, no Android SDK, no phone and no emulator, so the native half is verified the way tickets 08 and 11 verified theirs — as strings in files that have to agree — and the picture is verified pixel by pixel rather than by eye. The Dart side is 52 new app tests and 2 in the domain core: **861 and 384**, against 809 and 382 after ticket 20.

- [x] Export renders the entire garden at high resolution, independent of current pan and zoom — the export is not a screenshot of the viewport. **Structural rather than careful:** `GardenExporter` takes a layout, an atlas and a sky, and there is no argument a camera could arrive through; the projection is computed from `layout.plots`. See `docs/adr/0018-…`
- [x] The exported image includes background, season, theme, all plants and any decor, and excludes all UI chrome — one `GardenPainter` batch over one `GardenAtlas`, baked from the same `gardenAtlasRecipe` the screen bakes from. The chrome is not cropped away; it was never there
- [x] Free export carries a small tasteful corner watermark; premium export has none (REQ-035) — `Watermark?`, where premium is `null`. Pinned by a test that renders both and asserts **every differing pixel falls inside the mark's own box**
- [x] The image reaches the native share sheet on both platforms and saves correctly to the photo library, with photo permission handled where required — **one action, because on both platforms Save Image is a row inside the sheet.** The permission "where required" is iOS's `NSPhotoLibraryAddUsageDescription`, which the system shows and without which UIKit *terminates the app*. **Never run on a device**; see **Verification gaps**
- [x] Exporting a 200-plant garden completes in reasonable time with a progress indication, and does not block the UI or exhaust memory on a mid-range Android device — asynchronous through `Picture.toImage`, a `Drawing`/`Handing` progress state, and a pixel ceiling. **The device half is unmeasured**; see **Verification gaps**
- [x] Export is available from the garden view and from settings — two controls, one `exportGarden`, and a test that the two doors produce byte-identical images
- [x] `garden_exported` is emitted with premium status — the thirteenth of §7.1's thirteen, recorded when the sheet is up rather than at the tap

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/analytics/analytics_event.dart` | `AnalyticsEventName.gardenExported` and `GardenExported` — §7.1's table is now complete |
| `lib/src/export/garden_exporter.dart` | `GardenExport` and `GardenExporter`: the projection, the sheet, the pixel ratio, the picture |
| `lib/src/export/garden_watermark.dart` | `Watermark` — REQ-035's corner, as a value whose absence is the premium case |
| `lib/src/export/garden_share.dart` | The port and `ShareOutcome`. One method, and the reason there is one |
| `lib/src/export/channel_garden_share.dart` | The channel. The PNG crosses it, not a path |
| `lib/src/export/export_providers.dart` | `Exporting` (`Drawing`, `Handing`, `ExportFailed`), `GardenExportController`, `exportsCleanProvider` |
| `lib/src/garden/garden_atlas_recipe.dart` | Lifted out of `GardenView`: the one place colours become a texture, now that two callers bake one |
| `lib/src/garden/plant_palettes.dart` | `plantPaletteIn(GardenColors, …)` under the existing `plantPaletteFor(BuildContext, …)` — the export has no context to look a colour up through |
| `lib/src/features/garden/export_garden.dart` | `ExportKeys`, `exportGarden`, and the two controls: an app-bar action and a settings row |
| `lib/src/features/garden/garden_screen.dart` | The action, beside ticket 20's arranging |
| `lib/src/features/settings/settings_screen.dart` | The row, in the Garden section under the theme |
| `android/…/GardenSharePlugin.kt`, `res/xml/garden_share_paths.xml`, `AndroidManifest.xml`, `MainActivity.kt` | The chooser, the `FileProvider` and the one cache directory it vends |
| `ios/Runner/GardenSharePlugin.swift`, `AppDelegate.swift`, `Info.plist`, `project.pbxproj` | `UIActivityViewController`, the registration, and **the plist string that stops the app being killed** |
| `docs/adr/0018-an-export-is-the-garden-not-the-screen.md` | Why it is drawn and not captured, and what that costs |
| `CONTEXT.md` | Four words: export, sheet, watermark, share sheet — and a line added to camera |
| `test/support/celebrations.dart` | `dismissCelebrations`, lifted out of `milestone_test.dart` so any test with a seeded garden can get past the sheet |

## The four things worth knowing before picking up ticket 22 or 23

**The export cannot see the camera, and that is the whole design.** The first
criterion says the export is not a screenshot, and the ordinary Flutter answer —
a `RepaintBoundary` and `toImage(pixelRatio: 3)` — cannot satisfy it: the
boundary holds what the camera is showing, so a user zoomed into one corner
would export one corner. So the export re-draws through the *same painter* at a
projection fitted to `layout.plots`. Not "the exporter ignores the pan": there is
no parameter it could arrive through. The same move excludes the chrome — an app
bar is not something cropped away, it is something the picture never had.

**One recipe, two bakes, and a test holding them together.** The garden screen
owns an atlas and the export cannot borrow it — an export can start from
settings, where no garden is on screen to have baked one, and a texture the view
owns is a texture the view may dispose mid-render. So the export bakes its own
and disposes it immediately. The risk that creates is the two drifting apart: a
season or a theme reaching the screen and not the picture, invisible until
somebody shares a garden they do not have. `gardenAtlasRecipe` is the single
function both call, and *because it bakes the texture the screen is drawn from*
compares the signature of the on-screen atlas against the recipe an export
computes from settings — the case that could actually have differed.

**Resolution is a property of the raster, and the atlas is the ceiling.** The
picture is recorded in logical units with one `canvas.scale(ratio)` before
anything is drawn. The ratio aims for a 2048-pixel long edge and is capped at
`GardenAtlas.cellWidth / GardenProjection.spriteSide` — where the export samples
the texture one to one. **So a twelve-plot garden makes a smaller image than a
full one**, deliberately: past that ratio every pixel is interpolated and the
file grows while the picture does not. Ticket 23's real art raises this by
raising `cellWidth`, and nothing else changes.

**The share sheet and the photo library are one action, so there is one
method.** Both platforms put *Save Image* inside their own sheet. A second "save
to photos" button would be two ways to do one thing, one of which the platform
already offers inside the other — and it would put this app in the business of
managing somebody's photo library. That is also why no permission is requested
anywhere in Dart: Android needs none (the image crosses as a `content://` URI and
the receiving app saves under its own permissions) and on iOS the *system*
presents the prompt. What iOS needs from the app is one plist string, and it is
the sharpest failure in this ticket — see below.

## Two smaller decisions

**Export is offered to everybody, and the paywall is not behind it.** REQ-035
sells the corner of the image rather than the button: a free export is a real
export. So unlike ticket 20's arranging control this one never disappears, and
the reconciliation with REQ-041 goes the other way for the same reason it went
the way it did there — REQ-041 puts the paywall in settings and the theme picker
and nowhere else, so a locked control here would have refused with nowhere to
send anybody. Settings says which of the two exports the user is about to get,
*before* the sheet opens, because that is the door with room for a sentence.

**The app's first snack bar, and why.** Every other transient outcome in this app
is said inline beside its control — `_RestoreOutcome` is the precedent. A failed
export cannot be: one of its two doors is an app-bar action over a full-bleed
garden with nowhere to put a sentence, and a failure explained in settings and
swallowed on the garden tab would be the worse inconsistency. If a later ticket
adds a second one, this is the reasoning to check it against.

## Verification gaps

- **No native code was compiled and nothing has run on a device.** There is no
  Xcode, no Android SDK, no phone and no emulator on this machine. What is
  asserted instead is `test/platform/garden_share_wiring_test.dart`, on the model
  tickets 08 and 11 set: the channel name and both argument names agree across
  Dart, Kotlin and Swift; the `FileProvider` authority in the manifest is the one
  the plugin asks for; the provider's path is the directory the plugin writes to
  and nothing wider; the Swift file is in the Xcode target; and
  `NSPhotoLibraryAddUsageDescription` is present and non-empty. Those are the
  *silent* failures — every one of them is an export that renders perfectly and
  then does nothing, or crashes, with nothing in a log to say why. What none of
  it says is whether the chooser opens.
- **Nobody has looked at an exported image.** The watermark is asserted to be
  small, in the bottom-right, and the *only* difference between the free and paid
  renders — every disagreeing pixel falls inside its measured box. What that does
  not say is whether it reads as tasteful at a glance, or whether a 2048-pixel
  garden is a picture somebody wants to post. A designer should export one on a
  device. Related: the mark is set in Nunito, and the test host has no Nunito, so
  the *metrics* under test are the fallback face's. The box is computed from the
  same paragraph that is drawn, so the claim holds either way; the appearance is
  unverified.
- **"Reasonable time" and "mid-range Android" are arithmetic here, not
  measurements.** What is pinned is that the pixel count is bounded
  (`maximumPixels`, 16M — 64MB of RGBA at the worst moment), that a 200-plant
  garden encodes to well under 8MB, that the raster is off the Dart thread, and
  that the app stays interactive during it — a test taps through to the timer tab
  mid-export and finds it live. Nobody has held a mid-range phone and counted.
- **The photo-library save is entirely the platform's, and was never exercised.**
  The app hands over a file URL and a content URI; what Photos does with them is
  not this app's code. The iOS termination case in particular — an add-to-library
  prompt with no usage description — can only be seen by tapping Save Image on a
  real device, which is why the plist string has a comment beside it rather than
  being left as boilerplate.
- **`ShareOutcome` has no `cancelled`, on purpose.** Neither platform reports a
  dismissed sheet usefully, and the app has no business acting on it. A user who
  opened the sheet and changed their mind has exported their garden; `garden_exported`
  counts that, and does not count a sheet that never opened.
- **Pre-existing, still open:** `lib/src/data/database.dart` cites "ADR 0014" for
  ticket 17's decision not to backfill the event log, and no ADR 0014 exists.
  This ticket's ADR is 0018 rather than filling the gap, for the reason tickets
  18, 19 and 20 gave when they chose 0015, 0016 and 0017.
