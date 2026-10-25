# 14 — The garden changes with the seasons

**What to build:** In April the garden has cherry blossom and fresh green grass; in November, orange leaves drifting down; in January, snowfall and bare branches with the evergreens still holding colour. The user's garden feels connected to the world outside their window, and they did nothing to make it happen.

**Blocked by:** 07

**Status:** done — every criterion is built and covered, and like ticket 13 this one has **no device-shaped verification gap**: nothing here is native, nothing makes a sound and nothing talks to the OS, so a workstation can witness all of it. The Dart side is 28 new app tests and 13 in the domain core: 543 and 273 now, against 515 and 260 after ticket 13. Two things are written up below rather than left to be discovered: **REQ-019's "bare branches" ships as a recolour and not a silhouette**, because a plant's shape is its sprite's and the sprites are ticket 23's; and the **southern hemisphere is guessed from the device's time zone**, which is right in Sydney and falls back to the northern calendar in the many zones that keep no daylight saving to read.

- [x] The current season is derived from the device date and drives background, palette and a particle overlay per REQ-019
- [x] All four seasons are implemented and each can be forced in a debug affordance so reviewers do not have to wait for March
- [x] Crossing a season boundary while the app is open transitions over ~3 seconds with a colour crossfade rather than a hard cut
- [x] Particle overlays (falling leaves, snow, blossom) are gentle, ambient, and do not obscure plants or interfere with tap targets
- [x] Southern-hemisphere behaviour is decided and documented, not left to accident
- [x] Seasonal rendering costs are bounded — particle counts must not put the 200-plant garden below target frame rate
- [x] Season affects the garden view only; it does not alter which plant a session grows

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/garden/season.dart` | `Season.on`, `Season.boundaryAfter`, and `Hemisphere.fromDaylightSaving` — the whole rule, and no Flutter in it |
| `lib/src/design/palette.dart` | Nineteen seasonal hexes, in the one file hexes are allowed to live in |
| `lib/src/design/garden_colors.dart` | `foliage` and `evergreenFoliage`, so a season can turn leaves orange without turning buttons orange |
| `lib/src/design/season_palette.dart` | The four seasons as skins over `GardenColors`, and `Weather` — what falls, how much of it and how fast |
| `lib/src/garden/season_providers.dart` | `seasonProvider` (with the timer that notices a boundary), `hemisphereProvider`, `forcedSeasonProvider` |
| `lib/src/garden/season_transition.dart` | `SeasonTransition` — the garden partway between two seasons, and the one thing that knows how far |
| `lib/src/garden/season_weather.dart` | `SeasonWeather` and `WeatherPainter`: the blossom, the leaves and the snow |
| `lib/src/garden/plant_palettes.dart` | `evergreens` — the five species that keep their colour in January |
| `lib/src/features/garden/seasonal_garden.dart` | The substitution, and the three seconds it takes |
| `lib/src/features/garden/garden_screen.dart` | Where the season is put on, and where the weather sits in the stack |
| `lib/src/features/garden/garden_view.dart` | `rebakeInterval` — a floor on how often the atlas may be rebaked |
| `lib/src/features/settings/settings_screen.dart` | The **Season (debug)** chips, behind `kDebugMode` |
| `docs/adr/0011-…-derived-from-the-device-date.md` | The southern hemisphere, decided and written down |
| `CONTEXT.md` | The three words this ticket introduced: season, hemisphere, weather |

## The one thing worth knowing before picking up a dependent ticket

**A season is a substitution of one `ThemeExtension` over the garden's subtree, and that is
all it is.** `SeasonalGarden` wraps the garden tab in a `Theme` whose `GardenColors` came
from `SeasonPalette.of(season).applyTo(base)`. Everything the garden draws already read its
colours from there — the sky is `GardenColors.of(context).skyDay`, and the soil and foliage
are baked into the atlas out of the same values — so no painter, projection, layout or
sprite knows a season exists.

That is what makes the ticket's last criterion true *by construction* rather than by review.
There is no code path from `seasonProvider` to `SessionController`; a plant's type comes
from its session's planned duration and its species from a hash of its id, and neither has a
month in it. Ticket 19's themes are the same substitution at a different scope, and should
be built as one.

**Nothing records a season.** No column, no setting, no field on `Plant`. A garden opened
next November is an autumn garden whenever its plants went in, so this ticket needed no
migration and ticket 22's reset has nothing extra to clear.

## Two decisions worth reading before disagreeing with them

**The southern hemisphere is guessed, from the one thing a time zone says about latitude.**
Daylight saving moves a clock forward in that zone's own summer, so a July offset larger
than January's is northern and the reverse is southern. Equal offsets — most of the world,
including all of India and China and Brazil since 2019 — fall back to northern, which is
REQ-019's own reading of the calendar and exactly what the app would show if it never
looked. The guess is therefore never *worse* than not guessing, and it is right in Sydney,
Auckland and Santiago. The rejected alternatives, and the zones this still gets wrong
(Johannesburg, Brisbane, São Paulo), are in ADR 0011. The escape hatch is a
`GardenSettings` field and an override of `hemisphereProvider`; it is deliberately not
built, because a setting added on suspicion is a setting nobody can remove.

**The atlas has a floor on how often it may be rebaked, and the crossfade is why.** A bake
is an offscreen render of every sprite in the registry — 8ms, measured — and a season
crossfades over three seconds while moving the soil colour every frame of it. Without
`GardenView.rebakeInterval` that is 180 bakes inside three seconds. With it, the texture
*steps* through the change at 250ms while the sky crossfades smoothly over it, and the last
step lands on whatever the theme settled at. `test/garden/season_test.dart` asserts the
bound and was verified to go red without it. The cost is that a non-seasonal theme change —
the phone going dark — can also take up to 250ms to reach the plants.

## The limit this ticket ships with

**REQ-019's "bare branches" is a colour, not a shape.** `Palette.winterFoliage` draws a
January maple in bare wood; it does not draw it bare, because a plant's silhouette comes
from its sprite and the sprites belong to ticket 23. The seam is already in the right place
for the real fix — `PlantSpriteRegistry` is keyed by `(type, stage)`, and a winter canopy is
a different picture rather than a different colour — so ticket 23 inherits the choice with
nothing here to unpick. Snowfall and the evergreens holding their colour are real.

## What is bounded, and what the numbers are

`SeasonWeather.countIn` derives a count from the window's area and then caps it at
`SeasonWeather.maximum`, so the overlay is a fixed number of canvas primitives however large
the screen: 35 flakes in winter on a phone, around 20 in the other two seasons, and none at
all in summer — where the overlay is not built and its ticker never starts, because a ticker
with no work still asks for a frame every vsync.

| What | Per frame |
|---|---|
| The weather alone, one season | 0.06 – 0.14 ms |
| The weather alone, two seasons crossfading (the worst case) | 0.06 – 0.15 ms |
| 200 plants dragged, with snow over them | 2.1 – 2.6 ms, against 2.2 – 2.4 without |

Budgeted rather than merely recorded, including the two-layer crossfade that is the one
moment the per-season cap can be exceeded. The overlay takes no taps — its own
`IgnorePointer`, asserted with a `find.descendant` that was verified to go red when the
wrapper was removed — and nothing in it is above 0.75 alpha or covers more than half a
per cent of the window. See `docs/garden-performance-baseline.md`.
