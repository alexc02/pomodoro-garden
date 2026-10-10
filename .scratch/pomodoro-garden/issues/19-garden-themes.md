# 19 — Garden themes

> ⚠️ **Amended by the v2.1 decision that the app is free.**
> Three of this ticket's criteria are void: *free users can preview premium themes but
> not apply them*, *a purchase applies immediately*, and *an absent entitlement falls
> back to Zen*. All three themes apply to every user, `GardenTheme.unlocked` and the
> `premium` flag are gone, and the picker has no lock, no paywall route and no
> held-back note. What survives untouched is the table of twelve and the crossfade.
> See `docs/adr/0021-the-app-is-free-and-sells-nothing.md` and PRD §3.6.

**What to build:** The user picks a biome for their garden. Zen Garden is free and the default; Tropical Greenhouse and Wildflower Meadow are premium. Each reskins the background, soil and decor — and each still changes with the seasons, so the two systems compose rather than fight.

**Blocked by:** 18, 14

**Status:** done — every criterion is built and covered, and like tickets 13 and 14 this one has **no device-shaped verification gap**: nothing here is native, nothing talks to a store and nothing talks to the OS. It has a gap of a different kind, and it is the one the second criterion names: **twelve combinations were designed and asserted, and nobody has looked at them.** See **Verification gaps**. The Dart side is 41 new app tests and 10 in the domain core: 758 and 362, against 717 and 352 after ticket 18.

- [x] Three themes implemented per REQ-034, each reskinning garden background, soil tiles and decor — background and soil in full; **"decor" is a material token and the plot edging cut from it**, because ticket 20 is what puts decor objects in a garden. Its lanterns read `GardenColors.decor` and arrive already knowing which biome they are standing in
- [x] Every theme renders correctly in all four seasons — twelve combinations, all reviewed — **designed and asserted rather than seen.** All twelve are written out, distinct, filed under the right season and legibility-checked; see the gap below
- [x] Free users can preview premium themes but not apply them; attempting to apply routes to the paywall
- [x] A purchase applies immediately, with no relaunch needed to use a premium theme
- [x] Theme choice persists and is restored on launch
- [x] Switching themes crossfades rather than cutting, and does not disturb plant positions or growth
- [x] Plant sprites remain legible against all three backgrounds in both light and dark mode
- [x] If the entitlement is ever absent while a premium theme is selected, the app falls back to Zen without losing the user's stored preference

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/garden/garden_theme.dart` | The three biomes, and `unlocked(premium:)` — the whole of the last criterion, as one expression |
| `lib/src/design/palette.dart` | Forty-one new hexes, in the one file hexes are allowed to live in |
| `lib/src/design/theme_palette.dart` | **The twelve combinations**, written out, plus each theme's material |
| `lib/src/design/season_palette.dart` | Now one season *in one theme*; its four Zen constants moved into the table |
| `lib/src/design/garden_skin.dart` | `GardenSkin` — the pair the garden is actually painted from |
| `lib/src/design/garden_colors.dart` | `decor`, the one garden colour a season does not move |
| `lib/src/garden/garden_transition.dart` | Was `season_transition.dart`; now crosses two *skins* on one clock |
| `lib/src/garden/theme_providers.dart` | `chosenGardenThemeProvider`, `gardenThemeProvider`, `gardenSkinProvider` |
| `lib/src/garden/plant_atlas.dart` | The plot's edge is cut from the biome's material, not from its soil |
| `lib/src/features/garden/theme_picker.dart` | The picker, and REQ-041's second door |
| `lib/src/features/garden/seasonal_garden.dart` | The substitution, now over a skin |
| `lib/src/features/settings/settings_screen.dart` | The **Garden** section: the theme in force, and the way to change it |
| `lib/src/design/theme.dart` | `GardenTheme` → `AppTheme`, freeing REQ-034's name for REQ-034's idea |
| `docs/adr/0016-…-a-table-of-twelve.md` | Why a table and not a transform |
| `CONTEXT.md` | Three new words: theme, skin, decor |

## The four things worth knowing before picking up ticket 20 or 23

**A theme and a season meet in a table, not in a transform.** Both reach the same five
colours, and the tempting design — a season as a hue shift over whatever the theme
supplied — gives one answer where two are needed. A meadow in November is straw and seed
heads; a greenhouse in November is *green*, because the glass is the thing the season
cannot get through, and what autumn does to it is the light on the outside. No transform
gives both. So `ThemePalette` is twelve `SeasonPalette`s written by hand, and
"renders correctly" is a thing somebody decided rather than a thing arithmetic produced.
ADR 0016 has the rest.

**A skin is the unit, and there is one clock.** Below `SeasonalGarden` there is no such
thing as a theme change or a season change — only *the skin being arrived at has changed*.
That matters because a user can change theme in the three seconds a season is taking to
turn, and two controllers would let the sky finish arriving in January while the soil was
still on its way to the greenhouse. Ticket 14's mechanism is otherwise untouched: still one
`ThemeExtension` over the garden's subtree, still no painter, projection, layout or sprite
that knows any of this exists.

**One colour is deliberately outside the table.** `decor` — Zen's stone, the greenhouse's
teak, the meadow's fence wood — hangs off the theme and not off the pair. By January the
seasons have pulled all four of the other colours towards the same cold grey, and without a
constant the winter meadow and the winter Zen garden are nearly the same picture: the user
would have paid for something that vanishes for three months a year. **Ticket 20 should
draw its lanterns in `GardenColors.decor`** and will get biome-correct furniture for free.

**The entitlement is consulted when the garden is *drawn*, never when the choice is
written.** Two providers, and the split is the point: `chosenGardenThemeProvider` is what
the user picked, `gardenThemeProvider` is that filtered through `GardenTheme.unlocked`, and
only the second one paints. So the fallback cannot lose a preference — it returns a theme
rather than writing one — and a purchase applies on the next frame with nothing to re-save,
because nothing ever *applied* the theme. It is derived. A locked card also never writes,
so a free user cannot accumulate a preference they have not paid for.

## Two smaller decisions

**A purchase finishes the tap that started it.** Tapping a locked card sends the user to
the paywall; coming back from it *owning premium* applies the theme they asked for. The
paywall was the app's answer, not their intention, and a picker that had forgotten why it
sent them away would leave them tapping the same card twice. A purchase that did not
happen writes nothing.

**Settings names the choice, and the picker explains the rare disagreement.** In the one
state where chosen and applied differ — a premium theme on a device not currently entitled
to one — the card carries both marks and a sentence saying the garden is showing Zen until
premium is restored. A tick on a card whose garden is not on screen would read as a bug.

## Verification gaps

- **Nobody has looked at the twelve.** This is the second criterion's "all reviewed", and
  it is the one thing here a workstation cannot do. What *is* asserted is everything
  around it: all twelve are distinct pictures, each is filed under the season it claims,
  each theme's material is constant across its four seasons and unique among the three,
  and every theme still moves all four seasonal colours. What none of that can tell you is
  whether the greenhouse's autumn is *attractive*. A designer should sit with
  `theme_picker.dart` on a device and the season forced through all four from the debug
  affordance — twelve screens, and the swatches make it quick.
- **Legibility is a measured floor, not a judgement.** The criterion asks that plants stay
  legible against all three backgrounds. §5.1's garden is a deliberately low-contrast
  watercolour, so a WCAG ratio was the wrong instrument — it fails the *free* theme that
  has shipped since ticket 07, and "fixing" that would mean repainting ticket 14's
  approved palette. What is asserted instead is a CIE76 distance and a relative bar:
  **nothing sold is harder to read than the thing given away.** That caught one real
  regression — the meadow's winter bloom was a bleached grey-pink that measured *less*
  separable from its own frozen soil than anything in Zen, and is now a rosehip.
- **Dark mode is proved rather than sampled.** A skin overwrites every garden colour, so
  the garden is identical under `GardenColors.light` and `GardenColors.dark` and dark mode
  cannot introduce an illegibility light mode does not have. That is asserted directly for
  all twelve, which is better than twelve screenshots twice — but it does mean no dark-mode
  screenshot exists either.
- **`AppTheme` is a rename with no behaviour in it.** `GardenTheme` in `design/theme.dart`
  was the Material theme builder and REQ-034 needs that name for the biome. Six files, 19
  references, and the analyzer would have caught any miss — but it is the change most
  likely to confuse a reader of an older commit.
- **Pre-existing, still open:** `lib/src/data/database.dart` cites "ADR 0014" for ticket
  17's decision not to backfill the event log, and no ADR 0014 exists. This ticket's ADR is
  0016 rather than filling the gap, for the reason ticket 18 gave when it chose 0015.
