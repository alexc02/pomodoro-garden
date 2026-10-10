# A theme and a season meet in a table of twelve, not in a transform

> **Amended by [ADR 0021](0021-the-app-is-free-and-sells-nothing.md).** The app is free,
> so all three themes are the user's and *What the entitlement does, and does not, touch*
> below no longer describes the code: `GardenTheme.unlocked` and the entitlement it
> consulted are both gone, and `gardenThemeProvider` returns the stored choice unfiltered.
> Everything else here — the table of twelve, and why it is a table rather than a
> transform — is unchanged and still the reason the code is shaped as it is.

REQ-034 sells three garden themes. REQ-019 already turns the garden with the seasons. Both
reach the same five colours — sky, soil, foliage, bloom and the green an evergreen keeps —
and ticket 19 asks that they **compose rather than fight**, with all twelve combinations
reviewed.

The decision is how the two meet:

> Every pair is a value. `ThemePalette.of(theme).inSeason(season)` is a lookup into a
> table of twelve `SeasonPalette`s, each written out by hand.

## The alternative was cheaper and wrong

A season could have been a *transform* over whatever colours a theme supplied — a hue
rotation towards amber in autumn, a desaturation towards grey in winter. Three themes'
worth of base colours plus four transforms is twelve pictures out of about seven numbers,
and it would have made adding a fourth theme nearly free.

It would also have been twelve pictures nobody chose. The case that settles it:

- **A meadow in November** is straw and seed heads. Its foliage genuinely turns.
- **A greenhouse in November** is green, because the glass is the thing the season cannot
  get through. What autumn does to it is the *light on the outside* — amber on the roof,
  cold and flat in January — while the leaves under it stay exactly as they were.

Those are two different answers to "what does autumn do to this garden", and no single
transform gives both. A transform would have had to be told, per theme, which parts of
itself to skip — at which point it is a table with extra steps, and a table that is harder
to read.

"Renders correctly in all four seasons" is a claim about somebody's judgement. A table is
what makes it a thing that was decided rather than a thing that fell out of arithmetic.

## What the table costs, and what bounds it

Adding a fourth theme means writing four palettes rather than one. That cost is real and
it is visible: `garden_theme_test.dart` walks `GardenTheme.values × Season.values` and
fails until every cell is filled, distinct, and filed under the season it claims.

## One colour is deliberately outside the table

`decor` — the material a garden's furniture is cut from — hangs off the *theme* and not
off the pair. A season may move sky, soil, leaves and flowers; it never reaches the stone.

This is not an optimisation. By January the four seasonal colours have pulled every theme
towards the same cold grey, and without a constant the winter meadow and the winter Zen
garden are very nearly the same picture — the user would have paid for something that
disappears for three months of the year. Holding the material still is what keeps a theme
recognisable in the season that flattens the rest of it.

## The season stays underneath

Ticket 14 established that a season is *one `ThemeExtension` substituted over the garden's
subtree*, and that nothing downstream — no painter, projection, layout or sprite — knows a
season exists. A theme is the same substitution at a wider scope, and the two are applied
as one value:

> `GardenSkin(theme:, season:)` → `GardenColors`, and `GardenTransition` crossfades
> between two skins on a single clock.

**One clock is the point.** A user can change a theme in the three seconds a season is
taking to turn. Two transitions with a controller each would let the sky finish arriving
in January while the soil was still on its way to the greenhouse. Below `SeasonalGarden`
there is no such thing as a theme change or a season change — only *the skin the garden is
arriving at has changed*, which is one kind of event and is drawn one way.

## What the entitlement does, and does not, touch

REQ-039 gives the free tier one theme. The rule is a domain expression:

> `GardenTheme.unlocked(premium:)` — this theme if the device may have it, and Zen if it
> may not.

It returns a theme; it never writes one. That is the whole of the ticket's last criterion:
a premium theme on a device with no entitlement renders as Zen, and the stored preference
is untouched, so the garden comes back the moment the entitlement does. The two are
separate providers — `chosenGardenThemeProvider` for the picker, `gardenThemeProvider` for
everything that paints — because they are two different questions and a screen that
confused them would either forget the user's choice or hand out something unpaid for.

It is also why a purchase applies with no relaunch: nothing caches the entitlement and
nothing re-applies the theme, because nothing ever applied it. It is derived, every frame.
