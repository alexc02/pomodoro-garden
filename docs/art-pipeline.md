# The art pipeline

What a sprite is, how the app draws it, and how the art in `assets/art/` is made.

> **PRD v2.2: the art is paper-cut, and it is generated here.** There is no
> illustrator. Every plant and object in `assets/art/` is painted by
> `tool/generate_sprite_art.dart` in the paper-cut style the owner chose in
> ticket 28, over a watercolour and a flat version. See *The generator* at the
> end. The format below was written for a commissioned delivery and is still the
> contract: the generator meets it exactly as an illustrator would have had to.

## What a sprite is

Each drawing is delivered as **two PNGs of the same size**, plus one row in
`assets/art/manifest.json`.

| | What | Why |
|---|---|---|
| `<name>.png` | The drawing. Full colour, RGBA, transparent background. | This is the watercolour. It is what the user sees. |
| `<name>.roles.png` | A **role mask**, same dimensions. | This is what lets the palette reach the drawing. |
| a manifest row | The two paths, and the footprint. | See *The manifest*. |

### The role mask, which is the part that is not obvious

A watercolour plant is a fixed picture. The app's palette is not. Three separate
features move a plant's colours at runtime:

- **species** — a basil is a different green from a mint (there are 24 species
  across 7 types, and only 35 drawings);
- **season** — ticket 14 turns the whole garden over three seconds, four times a
  year;
- **theme** — ticket 19 sells three biomes, and PRD §9.1 budgets seasonal
  variants for *backgrounds* and for nothing else.

Thirty-five fixed PNGs would take all three away. So the mask says, per pixel,
which of three palette roles that pixel belongs to:

| Channel | Role, for a plant | Role, for an object |
|---|---|---|
| **Red** | foliage — stems, leaves, canopies | material — stone, teak, iron |
| **Green** | bloom — flowers, fruit, anything that is the reward colour | glow, or water for the pond |
| **Blue** | soil — the seed and the earth it sits in | shade — the ground it stands on |

A channel at 0 leaves that pixel the drawing's own colour. At full it becomes the
palette's colour. In between they **mix** — the palette colour is laid over the
drawing at the mask's strength, not multiplied into it.

That difference decides how a drawing has to be painted, and ticket 28 learned
it the hard way: a mask at one strength everywhere (the old stand-ins used 0.85)
flattens a drawing's light and shade almost to nothing, and a dark pixel under a
strong mask can come out *lighter* than its neighbours. So the generator splits
the work: **the drawing carries value, in warm neutral tones** — light where a
part is lit, dark where it is shaded — and **the mask's strength falls as the
drawing darkens**, from 0.95 in the light to 0.2 in the deepest shadow, so a
shadow stays a shadow in every season and every theme.

The mask's own alpha channel is ignored; only R, G and B are read. Leave it
opaque.

Practically, for an illustrator: paint the drawing, then paint a second flat
layer over it where every leaf is red, every petal is green and every bit of
earth is blue, and export that as the mask.

**A sprite may ship without a mask.** It is then art the palette cannot reach —
correct for something that should look identical in every season, and wrong for
any plant.

## The manifest

`assets/art/manifest.json` names every file. It is not a naming convention
because of one field:

```json
{
  "plants": [
    {
      "type": "herb",
      "stage": "sprout",
      "art": "assets/art/plants/herb_sprout.png",
      "roles": "assets/art/plants/herb_sprout.roles.png",
      "footprint": [0.31, 0.42, 0.69, 1.0]
    }
  ],
  "decor": [
    {
      "kind": "lantern",
      "art": "assets/art/decor/lantern.png",
      "roles": "assets/art/decor/lantern.roles.png",
      "footprint": [0.38, 0.30, 0.62, 1.0]
    }
  ]
}
```

**`footprint` is the tight bounds of the drawing's own non-transparent pixels**,
as fractions of the image: `[left, top, right, bottom]`, `[0,0,1,1]` being the
whole of it. Ticket 12 hit-tests against it — a plant is drawn standing on its
plot and growing *upwards*, so its box reaches over the two plots behind it, and
a footprint of the whole box would give a wildflower's empty sky to the finger
meant for the tree standing behind it.

It is carried in the manifest rather than computed at launch because computing it
means scanning the alpha channel of every image, on the cold path, against PRD
§4.4's 1.5-second budget. Whoever prepares the delivery computes it once; a
twenty-line script over the alpha channel is enough.

**A carried number is a number that can go stale**, and this one goes stale
silently: nothing at runtime ever compares it against the drawing, and a wrong
footprint is not a crash or a visible glitch but ticket 12's hit-test handing a
wildflower's empty sky to the finger meant for the tree behind it. So it is
checked instead — *the* reason `test/garden/art_delivery_test.dart` exists. It
re-derives every footprint from the alpha channel of the file the row names and
fails the build on a disagreement of more than a pixel and a half.

That check found the stand-ins wrong when it was written. `tool/generate_art.dart`
had been taking each footprint from the *sprite*'s `footprintIn`, and a sprite is
entitled to say it overhangs its box — ticket 04's large tree claims to reach 5%
above and below its square, which a rasterised PNG cannot. Every manifest row
therefore described ink that was not in the file. It now scans the PNG it just
wrote, which is also what the illustrator's delivery has to do.

`type`, `stage` and `kind` must spell the enum members exactly. A row naming
something the app does not know is a refused build, not a warning.

## What must be delivered

| | Count | Keyed by |
|---|---|---|
| Plants | **35** | 7 `PlantType` × 5 `GrowthStage` |
| Objects | **4** | `DecorKind` |

**35, not the 65 ticket 23's first criterion asks for**, and that is worth
stating plainly because it is a saving of about a third of PRD §9.1's
illustration budget. The ticket says *6 plant types × 5 stages, and all 7 bonus
plants × 5 stages*. The app does not work that way: REQ-021's bonus plants are a
**single `PlantType.bonus`** whose seven varieties are seven *species*, and
species is a palette difference, not a drawing. The registry is keyed by
`(type, stage)` and has been since ticket 04, deliberately —
`plant_sprite.dart` spells out why.

Delivering 65 drawings would need the registry re-keyed by species, which is a
logic change ticket 23's third criterion forbids. Either the ticket's count is
wrong or the architecture is; the architecture is the one that has shipped, and
the count is the one to correct.

## Size, density and format

**One resolution, delivered at the top end.** PRD §9.1 says so and the app is
built for it: *deliver at the highest density needed and downscale at build
time*. There are no `2.0x`/`3.0x` variant folders and there should not be —
Android's buckets (mdpi→xxxhdpi) and iOS's (@1x–@3x) do not line up, and one
oversized source downscaled by the GPU beats maintaining two ladders.

- **512×512 PNG**, square, for every plant and object.
- The largest anything is ever drawn is the timer screen at 3× — 88 logical
  points is 264 device pixels. The garden's ceiling is lower still: sprites there
  are baked into `GardenAtlas.cellWidth`, which is 192.
- **RGBA with real transparency.** No matte, no white background.
- The plant must stand on the **bottom edge** of its square and be centred
  horizontally. Both renderers hang it from that point.

### One thing to check on a device when the art lands

The atlas bakes every sprite into a **192-pixel cell**, and the garden at maximum
zoom on a 3× phone draws that cell at about 660 device pixels. That is a 3.4×
magnification, and it is a property of the atlas rather than of the source art —
raising `GardenAtlas.cellWidth` is the lever, at the cost of texture memory.

It has never mattered because the placeholders are flat colour, which magnifies
invisibly. **Watercolour will not.** This is the most likely place ticket 23's
fifth criterion — *no visible softness on a high-DPI device* — actually fails, and
it cannot be judged here. See `docs/performance-record.md`.

## What the app does with it

1. `ArtBundle.load` reads the manifest and decodes every image it names, all at
   once, at launch.
2. `ArtGate` holds the app on the `OpeningFrame` until that finishes. **This is
   the one piece of logic the art swap could not avoid** — every sprite paints
   synchronously and `GardenAtlas.bake` uses `toImageSync`, both so the garden
   never has a frame with no texture; decoding a PNG is asynchronous, and
   something has to sit between those two facts.
3. `plantSpriteRegistryProvider` and `decorSpriteRegistryProvider` serve
   `ImagePlantSpriteRegistry` / `ImageDecorSpriteRegistry` instead of the
   placeholder ones. **That is the whole of the swap above the asset layer:** two
   provider lines, and one file added to the allowlist in
   `test/garden/sprites_are_the_only_art_test.dart`.
4. Everything above the registry is untouched — the atlas, the batch, the depth
   sort, the hit-test, the timer screen, the export, the sway.

### Absent art and broken art are different

- **No `manifest.json` at all** → the build ships no art and runs on the
  placeholders. A legitimate state: the art is a delivery from outside this
  repository and a build can be made before it arrives.
- **A manifest that is present and wrong** — naming a file that is not there,
  missing a plant, spelling an enum member that does not exist → `ArtBundle.load`
  throws, the failure is reported, and the app opens on the placeholders. It is
  never half-applied, because a garden with holes in it ships to a store looking
  like a style choice.

## Checking a delivery

```sh
flutter test test/garden/art_bundle_test.dart test/garden/art_delivery_test.dart
```

Both run against whatever is in `assets/art/`, and they ask different questions.

**`art_bundle_test.dart` — does the pipeline work?** Does every plant type at
every stage resolve, does every one of them actually draw something, does the
palette still reach the art, does each stage draw a different picture from the
one before it. It would pass on thirty-five copies of the same smudge.

**`art_delivery_test.dart` — was the delivery prepared correctly?** This is the
acceptance check, and every line of it is a way a delivery can be wrong that
*nothing else would notice*:

| It checks | Because the failure is |
|---|---|
| every footprint against the alpha channel of its own file | silent — a wrong hit-test, no visible glitch |
| a plant stands on the bottom edge of its square, centred | a garden of levitating plants, on a device only |
| alpha is not thresholded | the *jagged edges on transparency* of criterion 5, a checkbox in an export dialog |
| art and mask are the same square, ≥ 264 px | a tint sliding off the drawing; magnified art |
| the drawing is not opaque to its corners | a matte — a plant standing in a white card |
| every plant has a role mask | that plant alone not turning in October |
| sprout → mature never shrinks, narrows or shortens | criterion 6's *jump* instead of an evolution |
| the set's weight against the binary headroom | criterion 7, and it is the number that moves |

Two notes on what it deliberately does **not** assert:

- **The seed is outside the growth check.** A seed is a bean on the soil rather
  than a small plant, and the shoot that comes up out of it is narrower than it
  was in all seven of ticket 04's types. Demanding monotone growth across that
  step would demand a worse picture. It gets its own check — that it sits in the
  soil rather than up the stem.
- **Nothing checks that two plant types are drawn differently**, and a real
  delivery must be. The stand-ins cannot support the check: every type shares one
  seed drawing by design, and `bonus` reuses `largeTree`'s shapes at four stages
  of five. **The commissioned set must not** — REQ-021's milestone reward that
  looks like an ordinary oak is not a reward — so this is the one acceptance
  criterion below that stays a human's job. Check it when the art lands, and turn
  it into a test at the same time.

What none of it can answer is whether the drawings are any good, whether a
watercolour survives being shrunk to a plot, and whether the twelve skin/season
combinations look right over them. Those need eyes and a phone.

## Soil, sky and weather: restyled in code, not swapped

These three have no file to swap: each is *colour applied to a shape*, so that
ticket 14's four seasons and ticket 19's three biomes are twelve rows in a table
and a season change crossfades over three seconds. PRD v2.2 keeps it that way
and gives them the paper-cut look in the renderer instead (ticket 35):

| | Drawn by | Paper-cut treatment |
|---|---|---|
| Soil / plot tiles | `GardenAtlas._paintSoil` | A frame in the biome's material, a soft shadow, and a sheet of soil laid on top, cut with a slightly irregular edge. Bare plots get a faint sheet |
| Sky | the skin's sky colour | The journal's paper fibres (`PaperPainter`) laid over it, behind the garden, painted once |
| Seasonal weather | `WeatherPainter` | Petals, almond leaves and six-pointed paper snowflakes, each with a small shadow as if lifted off the sky |

The summer "sun rays" overlay in PRD §9.1 is dropped: summer has a clear sky.

## The app icon

`tool/generate_icons.dart` builds every file both stores need from one mark:

- **Android** — `ic_launcher.png` at five densities, plus adaptive-icon
  `ic_launcher_foreground`/`_background` layers at 108dp and the
  `mipmap-anydpi-v26/ic_launcher.xml` that names them. The foreground draws
  inside the central 66dp, because that is all a launcher guarantees to keep
  after masking and parallax.
- **iOS** — all fifteen distinct sizes the appiconset asks for, opaque, corners
  left to the system.

The mark is a paper-cut seedling painted by the same generator
(`paintIconSeedling` in `tool/sprite_art/plants.dart`) at 1024 pixels and
coloured through the app's own tint, so it is the same paper as the garden.

The **Play feature graphic** is `tool/generate_store_art.dart`, written to
`docs/store/feature-graphic.png`. The **store screenshots** are the owner's, taken
from the iOS Simulator and the Android emulator (PRD v2.2 §6.3).

## The generator

```sh
flutter test tool/generate_sprite_art.dart    # paints every plant and object
flutter test tool/render_art_preview.dart     # renders them as the app shows them
flutter test tool/generate_icons.dart         # the app icon, every size
flutter test tool/generate_store_art.dart     # the Play feature graphic
```

| File | What it holds |
|---|---|
| `tool/sprite_art/wash.dart` | The painter: a sheet, the three finishes (`Finish.paperCut` is the app's; watercolour and flat are kept for comparison), outline helpers and an unpremultiplied PNG encoder |
| `tool/sprite_art/parts.dart` | The pieces every plant is cut from: soil, stalk, leaf, clump, blossom, bud |
| `tool/sprite_art/flower.dart`, `plants.dart` | The six types and the bonus plant at five stages, and the icon's seedling |
| `tool/sprite_art/decor.dart` | REQ-040's four objects |

Everything is deterministic: the same seeds give the same pixels, so a run that
changes nothing writes nothing new. Each piece keeps its seed from one stage to
the next, which is what makes the stages read as one plant growing.

`tool/generate_art.dart`, which rasterised ticket 04's placeholder shapes, is
**retired**: its test is skipped so it cannot overwrite the real art.

The paper-cut set is small, because flat paper compresses well. See
`docs/performance-record.md` for its weight in the release build.
