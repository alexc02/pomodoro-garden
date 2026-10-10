# 0018 — An export is the garden, not the screen

**Status:** accepted, ticket 21 · amended by
[ADR 0021](0021-the-app-is-free-and-sells-nothing.md)

> **There is one kind of export now, and it is the clean one.** The app is free, so the
> watermark is gone along with `Watermark`, `GardenExport.watermarked` and the
> `is_premium` parameter on §7.1's `garden_exported`. *A watermark is a value, and a
> premium export is its absence* below is the reasoning for a distinction the app no
> longer draws. What this ADR actually decides — that an export is **drawn** rather than
> captured, at a projection fitted to the garden and with no camera in it — is unchanged.

## The question

REQ-035 asks for a high-resolution image of the user's whole garden, in the
platform share sheet, watermarked for free users and clean for premium ones.
The garden is one `CustomPaint` over one texture, sitting under a camera the
user has been panning and pinching, inside a `Scaffold` with an app bar over it
and a nav bar under it.

The obvious way to get an image out of that is a `RepaintBoundary` around the
garden and `RenderRepaintBoundary.toImage(pixelRatio: 3)`. It is three lines, it
is what most Flutter apps do, and the ticket's first criterion rules it out in
so many words: *the export is not a screenshot of the viewport*.

So: where does the picture come from, and what makes it the whole garden rather
than the part of it that happened to be on screen?

## The decision

**The export re-draws the garden through the same painter, at a projection
fitted to the garden itself.** `GardenExporter` takes a `GardenLayout`, a
`GardenAtlas` and a sky colour, and builds a `Picture` from
`GardenProjection(pan: …)` — scale one, panned so the garden's own bounds sit at
a margin inside the sheet. There is no camera parameter, no `BuildContext`, no
`RepaintBoundary` and no widget tree in the call.

That is what makes each half of the criterion structural rather than careful:

- **Independent of pan and zoom** — because there is no argument a pan or a zoom
  could arrive through. It is not that the exporter ignores the camera; it
  cannot reach it.
- **The entire garden** — because the projection is computed from
  `layout.plots`, so every plot is on the sheet by construction.
- **No UI chrome** — because an app bar is not something the export crops away.
  It is something the export never had.

**The resolution is a property of the raster, not of the projection.** The
picture is recorded in logical units and `canvas.scale(ratio)` is applied once
before anything is drawn, so the same drawing comes out at any size. The ratio
aims for a long edge of 2048 pixels and is capped at
`GardenAtlas.cellWidth / GardenProjection.spriteSide` — the point at which the
export samples the atlas one to one.

That cap is why a new user's twelve plots make a smaller image than a full
garden does. It is the honest answer rather than a shortfall: past that ratio,
every pixel is interpolated from a neighbour, so the file would grow and the
picture would not.

**A watermark is a value, and a premium export is its absence.**
`GardenExporter.render` takes a `Watermark?`. A free export passes one and a
paid export passes null — not a mark drawn at zero opacity, not a mark clipped
away. So the two images are the same drawing plus or minus one box in one
corner, which is a thing a test can assert pixel by pixel, and does.

**The share sheet and the photo library are one action.** REQ-035 asks that the
image reach the native share sheet *and* save correctly to the photo library.
On both platforms those are the same gesture: **Save Image** is a row inside
`UIActivityViewController`, and the Photos app is a target inside Android's
chooser. So `GardenShare` has one method. A second "save to photos" button
beside the share one would be two ways to do one thing, one of which the
platform already offers inside the other.

This is also why there is no permission call anywhere in Dart. On Android none
is needed — the image crosses as a `content://` URI from a `FileProvider` and
the receiving app saves it under its own permissions. On iOS the *system*
presents the prompt, and the only thing the app must supply is the
`NSPhotoLibraryAddUsageDescription` string it shows.

## What it costs

**The export bakes a second atlas.** The garden screen owns one and the export
cannot borrow it: the export can be started from settings, where no garden is on
screen to have baked anything, and a texture the view owns is a texture the view
may dispose in the middle of a render. So it bakes its own from
`gardenAtlasRecipe` and disposes it as soon as the picture is recorded.

The risk that creates is the two falling out of step — a season, a theme or a
decor colour reaching the screen and not the picture, invisible until a user
shares a garden they do not have. It is answered by there being one recipe
function with two callers, and by a test comparing the atlas signature on the
garden tab with the recipe an export computes from settings.

**The render is asynchronous, and the app needs a progress state for it.**
`Picture.toImage` and `Image.toByteData` both return futures, which is what
keeps the UI alive while a few million pixels are rastered and encoded — and
which means the user watches a spinner for a moment. `Exporting` names the two
halves apart (`Drawing`, `Handing`) because they take their time for different
reasons and only one of them is this app's doing.

## What was rejected

**A `RepaintBoundary` capture at a large `pixelRatio`.** It cannot satisfy the
first criterion. The boundary contains what the camera is showing, so a user
zoomed into one corner exports one corner; and a boundary drawn wide enough to
hold the whole garden is a boundary that does not exist on screen. Every
workaround — an offscreen widget tree, a second `View` — is a second way of
laying the garden out, which is exactly the duplication ADR 0017's painter walk
exists to avoid.

**A fixed canvas size, with the garden centred in it.** Rejected because a
twelve-plot garden would be a postage stamp in the middle of an empty 2048-pixel
sky. The sheet is the garden's own size plus a margin, so an export is always a
picture of a garden rather than a picture of some sky with a garden in it.

**Writing the PNG to a file in Dart and sending the path.** Rejected because it
would put the cache directory, the file's lifetime and Android's `FileProvider`
authority into three places instead of one. The bytes cross the channel, and
each platform puts them where its own share mechanism can read them.

**Recording `garden_exported` at the tap.** Rejected: §7.1 counts exports that
happened. It is recorded once the sheet is open, so a render that failed is not
in the funnel and a broken device is not in the same column as a user sharing
their garden. What the user then chooses in the sheet is not reported back at
all — an app that knew which app you shared to would be collecting something PRD
§7.2 says it does not.
