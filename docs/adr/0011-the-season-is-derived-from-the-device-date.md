# The season is derived from the device date, and the hemisphere is guessed from its time zone

REQ-019 asks for a garden that changes with the seasons — blossom in April, orange leaves
in November, snow in January. The requirement's real content is in the sentence the ticket
adds to it: *the user did nothing to make it happen*. A season the user picks is a theme,
and the app already has one of those coming in ticket 19.

So the season is **derived, never stored and never chosen**:

> `Season.on(localDate, hemisphere:)` — three whole months each, turning at midnight on
> the first of March, June, September and December.

Nothing writes a season down. No plant records the season it was grown in, no setting
holds one, and no migration was needed to add the feature. A garden opened next November
is an autumn garden whatever is in it, and a plant grown in the snow is not a winter
plant — it is a plant, in a garden that happens to be snowy today.

## Meteorological, not astronomical

Astronomical seasons turn at the solstices and equinoxes, which move by a day or two a
year and need either an ephemeris or a polynomial approximation of one. Meteorological
seasons are three calendar months each.

The astronomical version costs arithmetic nobody can check by eye and buys a boundary
nobody can see. The meteorological one also makes a boundary an **instant a timer can be
aimed at exactly**, which is what makes the "crossing a boundary with the app open" case
implementable at all: `Season.boundaryAfter` is `DateTime(year, nextMultipleOfThree)`.

## Local time, in an app that is otherwise UTC everywhere

ADR 0001 anchors a session to a UTC instant and derives everything from it, precisely so
that a device changing time zone mid-session cannot move the countdown. This is the one
rule that wants the opposite: **a season is what is outside the user's window**, and the
window is in local time. `seasonProvider` is the only place in the app that calls
`toLocal()`, and it is the presentation edge ADR 0001's rule points at.

## The southern hemisphere

A garden showing snow to somebody in Sydney in January is REQ-019 failing at the thing it
was for. There were three ways to avoid it.

**Ask the user.** A hemisphere setting. Rejected: it is the feature's own premise being
handed back to the user to configure, and it is a question most people would answer once
and then wonder why they were asked.

**Ask the phone where it is.** A location permission, for decoration. Rejected: it is a
disproportionate thing to prompt for, it costs the app a permission dialog on a screen
about plants, and a user who declines is back to guessing anyway.

**Read the time zone.** The device already has one, no permission gates it, and it says
one useful thing about latitude: *when* the zone puts its clocks forward. Daylight saving
moves a clock forward in that zone's own summer, so:

```dart
Hemisphere.fromDaylightSaving(
  january: DateTime(year, 1).timeZoneOffset,
  july:    DateTime(year, 7).timeZoneOffset,
);
```

July offset larger → northern. January offset larger → southern. **Equal → northern.**

This is the decision, and its limit is the point of writing it down: **a zone with no
daylight saving cannot be read at all.** That is most of the world — India, China, almost
all of Africa, Brazil since 2019 — so Johannesburg gets northern seasons and shows snow in
July. Two things make that acceptable rather than a bug shipped knowingly:

- The fallback is exactly what the app would do if it never looked. REQ-019's own text is
  a northern calendar. The guess is therefore **never worse than not guessing**, and it is
  strictly better in Sydney, Auckland, Santiago and everywhere else that keeps southern
  daylight saving.
- A great many of the zones it cannot read are tropical, where a four-season calendar is a
  fiction in either hemisphere.

If it turns out not to be good enough, the escape hatch is the setting rejected above, and
it is one field on `GardenSettings` and one override of `hemisphereProvider` away. It is
deliberately not built yet, because a setting added on suspicion is a setting nobody can
ever remove.

## What a season is allowed to touch

One thing: the `GardenColors` in the theme the garden tab is built under, substituted by
`SeasonalGarden` and by nothing else.

That is what keeps the ticket's last requirement true by construction rather than by
review — *season affects the garden view only; it does not alter which plant a session
grows*. A plant's type comes from its session's planned duration and its species from a
hash of the session's id (ADR: "a plant is decided by its session, not rolled for"), and
neither of those has a month in it. There is no code path from `seasonProvider` to
`SessionController`, and the test that would catch one growing is in
`test/garden/season_test.dart`.

## Consequences

- `GardenColors` gains `foliage` and `evergreenFoliage`. Foliage previously came from
  `ColorScheme.primary`, which would have meant a season turning the app's *buttons*
  orange in October to turn its leaves orange.
- `GardenView` gains a floor on how often the atlas may be rebaked
  (`GardenView.rebakeInterval`). A bake is an offscreen render of every sprite, and the
  crossfade moves the soil colour every frame for three seconds; without the floor a
  change of season would be a hundred and eighty bakes and most of a second of dropped
  frames. With it the texture steps while the sky crossfades smoothly over it.
- The weather is capped rather than emergent (`SeasonWeather.maximum`), so the overlay's
  cost cannot grow with the size of the window. Measured at 0.06–0.13ms a frame, against a
  garden that costs 0.2ms.
- **REQ-019's "bare branches" ships as a recolour, not a silhouette.** A plant's shape is
  its sprite's, and the sprites are ticket 23's; a January maple is therefore drawn in bare
  wood rather than drawn bare. `PlantSpriteRegistry` is keyed by `(type, stage)` and a
  winter canopy is a different picture, so the fix is ticket 23's to make and nothing here
  stands in its way.
- `seasonProvider` holds an hourly timer while the garden is built, so a device whose date
  is corrected forward is picked up within the hour rather than at the next boundary. It
  is a foreground timer disposed with the provider; REQ-005's promise about what runs in
  the background is untouched.
